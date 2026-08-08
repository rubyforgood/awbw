module AuthorCreditable
  extend ActiveSupport::Concern

  # How a credit renders comes from the credited person's profile, not from the record.
  # `author_credit_preference` is retained as the record of what the submitter consented
  # to at submission time, and is human-editable only on the author credit divergences
  # page. It no longer drives display — with one exception: a stored "anonymous" is
  # always honored, because anonymity is inherently per-item (a person may want four
  # stories credited and the fifth not) and because nothing should be able to
  # de-anonymize an item that was submitted anonymously.
  AUTHOR_CREDIT_PREFERENCES = %w[full_name first_name_last_initial first_name_only last_name_only anonymous].freeze

  ANONYMOUS = "anonymous"

  ADMIN_FORM_OPTIONS = {
    "Full name" => "full_name",
    "First name, last initial" => "first_name_last_initial",
    "First name only" => "first_name_only",
    "Last name only" => "last_name_only",
    "Anonymous" => "anonymous"
  }.freeze

  included do
    # Snapshot the credited person's profile preference on create, so the column keeps
    # recording consent-at-submission without a human ever picking it.
    before_create :snapshot_author_credit_preference
    # A blank preference means "no per-item override, just follow the profile" — store
    # it as nil so the divergence worklist (which excludes nil) never re-flags it.
    normalizes :author_credit_preference, with: ->(value) { value.presence }
    validates :author_credit_preference, inclusion: { in: AUTHOR_CREDIT_PREFERENCES }, allow_blank: true

    # Filter to content explicitly authored by a person (belongs_to :author);
    # no-op when person_id is blank. Only models with an author_id column use it.
    scope :authored_by, ->(person_id) { where(author_id: person_id) if person_id.present? }

    # Filter to content whose creating user belongs to a person. This is the only
    # authorship link the idea models have (they carry no author_id of their own),
    # and it's keyed on the person rather than a user id so it stays correct — and
    # empty — for a person with no user account.
    scope :created_by_person, ->(person_id) { joins(:created_by).where(users: { person_id: person_id }) }
  end

  # The linkable credited person, in precedence order: the explicit/legacy author
  # person, otherwise the creating user's person. This is what views link to.
  def author_person
    primary_author_person || created_by&.person
  end

  # The credited author person that is *not* the creator fallback — the explicit
  # author.
  def primary_author_person
    author if respond_to?(:author)
  end

  # A legacy free-text author name (no linkable person), ranked between the
  # explicit author and the creator. Overridden by models that have one
  # (Workshop, Resource).
  def legacy_author_name_text
    nil
  end

  # Display string for the credited author, formatted by that person's profile.
  # Precedence: the primary author person, then the legacy free-text name, then the
  # creating user's person, then `missing_author_label`.
  def author_credit
    person = primary_author_person
    return credit_for(person) if person
    return legacy_author_name_text if legacy_author_name_text.present?
    creator = created_by&.person
    creator ? credit_for(creator) : missing_author_label
  end

  # The person the credit should link to, or nil when the credit must not resolve
  # to a profile. Only an explicit/legacy author links: a credit that falls back
  # to the creating user's person is shown as plain text, because that person
  # never declared authorship (and the record isn't listed on their profile
  # either). Anonymous never links.
  def author_credit_person
    person = primary_author_person
    person && !credit_anonymous?(person) ? person : nil
  end

  # Anonymity is a one-way latch: the profile can set it, the record can set it,
  # and neither can strip it from the other.
  def credit_anonymous?(person)
    person.contributions_anonymous? || author_credit_preference == ANONYMOUS
  end

  # True when the stored consent snapshot no longer agrees with the credited
  # person's current profile — surfaced as a warning on the record's form and as a
  # row on the author credit divergences page.
  def author_credit_diverged?
    return false if author_credit_preference.blank?
    person = author_person
    person.present? && author_credit_preference != person.effective_author_credit_preference
  end

  # Shown when there is no credited person or legacy name. Overridable per model
  # (e.g. Workshop shows "Facilitator").
  def missing_author_label
    "Anonymous"
  end

  def snapshot_author_credit_preference
    # Promotion services copy the originating idea's snapshot forward — keep it.
    return if author_credit_preference.present?
    person = primary_author_person || created_by&.person
    self.author_credit_preference = person.effective_author_credit_preference if person
  end

  private def credit_for(person)
    return "Anonymous" if credit_anonymous?(person)
    person.name.presence || missing_author_label
  end

  class_methods do
    # Legacy free-text columns (fully qualified, e.g. "resources.legacy_author_name")
    # that also hold an author's name. Overridden per model that has one.
    def legacy_author_name_columns
      []
    end

    # Records whose credited author's name resembles `query`: the explicit author
    # person, the creating user's person, plus any legacy sources the model folds
    # in. Uses explicit LEFT JOIN aliases so it composes safely — SearchCop can't
    # join `people` more than once, so callers OR this into full-text results via
    # an id subquery.
    def by_credited_person_name(query)
      sanitized = query.to_s.strip.gsub(/\s+/, "")
      return none if sanitized.blank?

      clauses = credited_person_aliases.map { |a| credited_person_match_sql(a) }
      clauses += legacy_author_name_columns.map { |col| legacy_author_name_match_sql(col) }
      joins(credited_person_join_sql).where(clauses.join(" OR "), name: "%#{sanitized}%")
    end

    # Orders by the credited author's name, matching `author_person` precedence:
    # explicit author, then any legacy sources, then the creating user's person.
    def order_by_author(direction)
      ascending = direction.to_s.casecmp("asc").zero?
      # By first name then last name, matching the credit displayed by default
      # ("First Last"), so the ordering follows the visible column.
      joins(credited_person_join_sql)
        .reorder(coalesced_author_arel(:first_name, ascending), coalesced_author_arel(:last_name, ascending))
    end

    private

    # Person SQL aliases in credit precedence order.
    def credited_person_aliases
      aliases = []
      aliases << "credited_author" if column_names.include?("author_id")
      aliases << "credited_creator"
      aliases
    end

    # Explicit LEFT JOINs (as raw SQL strings with unique aliases) reaching every
    # person that can be credited, so the aliases never collide with SearchCop's
    # or Rails' own joins.
    def credited_person_join_sql
      sql = []
      if column_names.include?("author_id")
        sql << "LEFT OUTER JOIN people credited_author ON credited_author.id = #{table_name}.author_id"
      end
      sql << "LEFT OUTER JOIN users credited_creator_user ON credited_creator_user.id = #{table_name}.created_by_id"
      sql << "LEFT OUTER JOIN people credited_creator ON credited_creator.id = credited_creator_user.person_id"
      sql
    end

    # Arel COALESCE over every credited person alias (and legacy name column),
    # so the ORDER BY carries no interpolated SQL. Aliases and column names come
    # from model config / column_names, never user input.
    def coalesced_author_arel(field, ascending)
      parts = credited_person_aliases.map { |sql_alias| Arel::Table.new(sql_alias)[field] }
      parts += legacy_author_name_columns.map do |col|
        table, column = col.split(".")
        Arel::Table.new(table)[column]
      end
      node = Arel::Nodes::NamedFunction.new("COALESCE", parts)
      ascending ? node.asc : node.desc
    end

    # Match only on the name parts the credit actually displays, so search can't
    # surface what the credit hides: an anonymous credit matches nothing, a
    # "first name only" credit isn't findable by last name, and a "first name,
    # last initial" credit matches the initial rather than the whole last name.
    def credited_person_match_sql(sql_alias)
      first = "#{sql_alias}.first_name"
      last = "#{sql_alias}.last_name"
      preference = "COALESCE(#{sql_alias}.display_name_preference, 'full_name')"

      by_preference = {
        "full_name" => [ "CONCAT(#{first}, #{last})", "CONCAT(#{last}, #{first})", first, last ],
        "first_name_last_initial" => [ "CONCAT(#{first}, LEFT(#{last}, 1))", first ],
        "first_name_only" => [ first ],
        "last_name_only" => [ last ]
      }.map do |value, expressions|
        "(#{preference} = '#{value}' AND (#{expressions.map { |e| name_like(e) }.join(' OR ')}))"
      end

      "(#{sql_alias}.contributions_anonymous = FALSE AND #{not_anonymous_sql} AND (#{by_preference.join(' OR ')}))"
    end

    # Legacy free-text author names have no person, so only the record's own
    # anonymity applies.
    def legacy_author_name_match_sql(column)
      "(#{not_anonymous_sql} AND #{name_like(column)})"
    end

    def not_anonymous_sql
      "(#{table_name}.author_credit_preference IS NULL OR " \
        "#{table_name}.author_credit_preference <> '#{AuthorCreditable::ANONYMOUS}')"
    end

    def name_like(expression)
      "LOWER(REPLACE(#{expression}, ' ', '')) LIKE :name"
    end
  end
end
