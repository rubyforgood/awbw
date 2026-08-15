module AuthorCreditable
  extend ActiveSupport::Concern

  # Credits render from the credited person's profile. This column is the consent
  # snapshot and no longer drives display, except "anonymous", which is always honored.
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
    before_create :snapshot_author_credit_preference
    # Blank means "follow the profile"; nil keeps it off the divergence worklist.
    normalizes :author_credit_preference, with: ->(value) { value.presence }
    validates :author_credit_preference, inclusion: { in: AUTHOR_CREDIT_PREFERENCES }, allow_blank: true

    # Filter to content explicitly authored by a person (belongs_to :author);
    # no-op when person_id is blank. Only models with an author_id column use it.
    scope :authored_by, ->(person_id) { where(author_id: person_id) if person_id.present? }

    # `where.not` alone would drop NULL rows, which mean "follow the profile".
    scope :credited_openly, -> {
      where(author_credit_preference: nil).or(where.not(author_credit_preference: ANONYMOUS))
    }

    # The idea models' only authorship link. Keyed on person, not user, so it stays
    # empty for a person with no account.
    scope :created_by_person, ->(person_id) { joins(:created_by).where(users: { person_id: person_id }) }
  end

  # The linkable credited person, in precedence order: the explicit/legacy author
  # person, otherwise the creating user's person. This is what views link to.
  def author_person
    primary_author_person || created_by&.person
  end

  def primary_author_person
    author if respond_to?(:author)
  end

  # Free-text author name with no linkable person. Overridden by Workshop, Resource.
  def legacy_author_name_text
    nil
  end

  def author_credit
    # Outranks every source, including a legacy name no profile can suppress.
    return "Anonymous" if author_credit_preference == ANONYMOUS
    person = primary_author_person
    return credit_for(person) if person
    return legacy_author_name_text if legacy_author_name_text.present?
    creator = created_by&.person
    creator ? credit_for(creator) : missing_author_label
  end

  # Only an explicit author links — a creator fallback never declared authorship.
  def author_credit_person
    person = primary_author_person
    person && !credit_anonymous?(person) ? person : nil
  end

  # A one-way latch: either side can set it, neither can strip it from the other.
  def credit_anonymous?(person)
    person.anonymous_contributions? || author_credit_preference == ANONYMOUS
  end

  # A legacy name follows nobody's profile, so those have no governing person.
  def credit_governing_person
    person = primary_author_person
    return person if person
    return nil if legacy_author_name_text.present?
    created_by&.person
  end

  # Snapshot no longer agrees with the governing profile.
  def author_credit_diverged?
    return false if author_credit_preference.blank?
    person = credit_governing_person
    person.present? && author_credit_preference != person.effective_author_credit_preference
  end

  # Shown when there's no credited person or legacy name. The portal is behind a
  # login, so this names the org's facilitators rather than hiding behind
  # "Anonymous", which would read as a deliberate privacy choice.
  def missing_author_label
    "AWBW Facilitator"
  end

  def snapshot_author_credit_preference
    # Promotion services copy the originating idea's snapshot forward — keep it.
    return if author_credit_preference.present?
    # Only the governing profile, so a legacy credit doesn't snapshot the profile of
    # whoever entered it and then read as drift against it.
    person = credit_governing_person
    self.author_credit_preference = person.effective_author_credit_preference if person
  end

  private def credit_for(person)
    return "Anonymous" if credit_anonymous?(person)
    person.name.presence || missing_author_label
  end

  class_methods do
    # Fully-qualified legacy name columns, e.g. "resources.legacy_author_name".
    def legacy_author_name_columns
      []
    end

    # Explicit LEFT JOIN aliases, because SearchCop can't join `people` twice —
    # callers OR this into full-text results via an id subquery.
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

    def credited_person_join_sql
      sql = []
      if column_names.include?("author_id")
        sql << "LEFT OUTER JOIN people credited_author ON credited_author.id = #{table_name}.author_id"
      end
      sql << "LEFT OUTER JOIN users credited_creator_user ON credited_creator_user.id = #{table_name}.created_by_id"
      sql << "LEFT OUTER JOIN people credited_creator ON credited_creator.id = credited_creator_user.person_id"
      sql
    end

    # Arel keeps interpolated SQL out of the ORDER BY. Ordered author → legacy →
    # creator to match `author_credit`, so a row sorts under the name it displays.
    def coalesced_author_arel(field, ascending)
      parts = []
      parts << Arel::Table.new("credited_author")[field] if column_names.include?("author_id")
      parts += legacy_author_name_columns.map do |col|
        table, column = col.split(".")
        Arel::Table.new(table)[column]
      end
      parts << Arel::Table.new("credited_creator")[field]
      node = Arel::Nodes::NamedFunction.new("COALESCE", parts)
      ascending ? node.asc : node.desc
    end

    # Match only the name parts the credit displays, so search can't surface what
    # the credit hides.
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

      # A legacy name outranks the creator in the credit, so the creator's name isn't
      # displayed on those rows and mustn't find them either.
      gate = sql_alias == "credited_creator" ? " AND #{no_legacy_name_sql}" : ""
      "(#{sql_alias}.anonymous_contributions = FALSE AND #{not_anonymous_sql}#{gate} AND (#{by_preference.join(' OR ')}))"
    end

    def no_legacy_name_sql
      return "1 = 1" if legacy_author_name_columns.empty?
      legacy_author_name_columns.map { |col| "(#{col} IS NULL OR #{col} = '')" }.join(" AND ")
    end

    # No person behind a legacy name, so only the record's own anonymity applies.
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
