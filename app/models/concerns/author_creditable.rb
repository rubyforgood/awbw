module AuthorCreditable
  extend ActiveSupport::Concern

  # A record's stored preference is the submitter's consent snapshot. When set it
  # wins for display (honoring what they chose at submission); otherwise the credited
  # person's current profile decides. "anonymous" (either side) is always honored.
  AUTHOR_CREDIT_PREFERENCES = %w[full_name first_name_last_initial first_name_only last_name_only anonymous].freeze

  ANONYMOUS = "anonymous"

  # Read through `anonymous_author_label` / `missing_author_label` from a record, so a
  # model can override; reference the constants directly only where no record is in hand.
  ANONYMOUS_AUTHOR_LABEL = "AWBW Facilitator".freeze
  MISSING_AUTHOR_LABEL = "AWBW Staff".freeze

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
    person = primary_author_person
    # credit_for suppresses an anonymous author to the facilitator label.
    return credit_for(person) if person
    # Anonymous suppresses a legacy name too; with no person behind it, nothing is left.
    return legacy_author_name_text if legacy_author_name_text.present? && author_credit_preference != ANONYMOUS
    # No author at all, so it reads as the org's own content.
    missing_author_label
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

  # Only an explicit author has a governing profile. A legacy name follows nobody's,
  # and an unattributed record credits nobody, so neither has a governing person.
  def credit_governing_person
    primary_author_person
  end

  # Snapshot no longer agrees with the governing profile.
  def author_credit_diverged?
    return false if author_credit_preference.blank?
    person = credit_governing_person
    person.present? && author_credit_preference != person.effective_author_credit_preference
  end

  # A named author who opted out of the credit — still a facilitator's content,
  # just shown without their name rather than hiding behind "Anonymous".
  def anonymous_author_label
    ANONYMOUS_AUTHOR_LABEL
  end

  # No author at all, so the content reads as the org's own.
  def missing_author_label
    MISSING_AUTHOR_LABEL
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
    return anonymous_author_label if credit_anonymous?(person)
    # The record's own preference wins over the person's profile; fall back to the
    # profile when the record didn't store one.
    preference = author_credit_preference.presence || person.display_name_preference
    person.name_for(preference).presence || anonymous_author_label
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
      return none if clauses.empty?

      joins(credited_person_join_sql).where(clauses.join(" OR "), name: "%#{sanitized}%")
    end

    # Orders by the credited author's name, matching `author_person` precedence:
    # explicit author, then any legacy sources, then the creating user's person.
    def order_by_author(direction)
      return all if credited_person_aliases.empty? && legacy_author_name_columns.empty?

      ascending = direction.to_s.casecmp("asc").zero?
      # By first name then last name, matching the credit displayed by default
      # ("First Last"), so the ordering follows the visible column.
      joins(credited_person_join_sql)
        .reorder(coalesced_author_arel(:first_name, ascending), coalesced_author_arel(:last_name, ascending))
    end

    private

    # Only an explicit author is ever credited, so search and sort reach that person
    # alone — and nobody at all on the idea models, which have no author_id.
    def credited_person_aliases
      column_names.include?("author_id") ? [ "credited_author" ] : []
    end

    def credited_person_join_sql
      return [] if credited_person_aliases.empty?

      [ "LEFT OUTER JOIN people credited_author ON credited_author.id = #{table_name}.author_id" ]
    end

    # Arel keeps interpolated SQL out of the ORDER BY. Same precedence as
    # `author_credit`, so a row sorts under the name it displays.
    def coalesced_author_arel(field, ascending)
      parts = credited_person_aliases.map { |sql_alias| Arel::Table.new(sql_alias)[field] }
      parts += legacy_author_name_columns.map do |col|
        table, column = col.split(".")
        Arel::Table.new(table)[column]
      end
      node = Arel::Nodes::NamedFunction.new("COALESCE", parts)
      ascending ? node.asc : node.desc
    end

    # Match only the name parts the credit displays, so search can't surface what
    # the credit hides.
    def credited_person_match_sql(sql_alias)
      first = "#{sql_alias}.first_name"
      last = "#{sql_alias}.last_name"
      # The record's own preference wins over the profile, matching `credit_for`.
      preference = "COALESCE(#{table_name}.author_credit_preference, #{sql_alias}.display_name_preference, 'full_name')"

      by_preference = {
        "full_name" => [ "CONCAT(#{first}, #{last})", "CONCAT(#{last}, #{first})", first, last ],
        "first_name_last_initial" => [ "CONCAT(#{first}, LEFT(#{last}, 1))", first ],
        "first_name_only" => [ first ],
        "last_name_only" => [ last ]
      }.map do |value, expressions|
        "(#{preference} = '#{value}' AND (#{expressions.map { |e| name_like(e) }.join(' OR ')}))"
      end

      "(#{sql_alias}.anonymous_contributions = FALSE AND #{not_anonymous_sql} AND (#{by_preference.join(' OR ')}))"
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
