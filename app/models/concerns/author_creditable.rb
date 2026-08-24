module AuthorCreditable
  extend ActiveSupport::Concern

  # The credited person's profile decides how a credit renders. A record's stored
  # preference is the submitter's request, recorded at submission and surfaced on the
  # author credit divergences page for an admin to apply to the profile — it does not
  # drive display on its own. "anonymous" (either side) is always honored.
  AUTHOR_CREDIT_PREFERENCES = %w[full_name first_name_last_initial first_name_only last_name_only anonymous].freeze

  ANONYMOUS = "anonymous"

  # Join aliases for the people a record credits, in display precedence order.
  CREDITED_AUTHOR_ALIAS = "credited_author".freeze
  CREATOR_PERSON_ALIAS = "creator_person".freeze

  # The generic credit AWBW puts on content with no named credit. Content AWBW produces
  # itself — news, workshops, resources — reads as "AWBW Staff"; everything else,
  # including facilitator submissions and the idea forms, reads as "AWBW Facilitator".
  # Both the unattributed and the opted-out (anonymous) cases fall to this same per-model
  # label. Read it through `anonymous_author_label` / `missing_author_label` from a
  # record where one is in hand — the label varies by model (see `credits_to_org`).
  FACILITATOR_AUTHOR_LABEL = "AWBW Facilitator".freeze
  ORG_AUTHOR_LABEL = "AWBW Staff".freeze

  # Submitter-facing wording. Blank is the default and means "follow my profile" —
  # anything else is a request an admin applies to the profile on the divergences page.
  SUBMITTER_FORM_OPTIONS = {
    "My full name" => "full_name",
    "My first name and last initial" => "first_name_last_initial",
    "My first name only" => "first_name_only",
    "My last name only" => "last_name_only",
    "Don't credit me by name" => "anonymous"
  }.freeze

  ADMIN_FORM_OPTIONS = {
    "Full name" => "full_name",
    "First name, last initial" => "first_name_last_initial",
    "First name only" => "first_name_only",
    "Last name only" => "last_name_only",
    "Anonymous" => "anonymous"
  }.freeze

  included do
    # Which generic label an unattributed record credits to. Facilitator-submitted
    # content follows the facilitator label; org-produced models flip it to the org
    # label with `credits_to_org`.
    class_attribute :unattributed_author_label, instance_writer: false, default: FACILITATOR_AUTHOR_LABEL

    # Whether the submitting account's person is credited when no explicit author is
    # on file. Off by default — on most models the creator entered the content rather
    # than writing it. Turn it on with `credits_creator`.
    class_attribute :creator_credited, instance_writer: false, default: false

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

    # Everything a person is credited for under author_person semantics: the
    # explicit author, or — the legacy fallback, only when nobody else is the
    # explicit author — anything their user account created. The read-side twin
    # of #author_person, for profile listings.
    #
    # The created_by fallback only matters on the select models that carry legacy,
    # author-less rows (workshop variations, monthly reports, and older workshop
    # logs from before we set author on create). On models where author is always
    # populated, the fallback clause matches nothing and this is just authored_by.
    scope :credited_to_person, ->(person) {
      if person
        where(author_id: person.id)
          .or(where(author_id: nil, created_by_id: User.where(person_id: person.id).select(:id)))
      else
        none
      end
    }
  end

  # The linkable credited person, in precedence order: the explicit/legacy author
  # person, otherwise the creating user's person. This is what views link to.
  def author_person
    primary_author_person || created_by&.person
  end

  def primary_author_person
    author if respond_to?(:author)
  end

  # The creator's person, on models where the submitter is the author
  # (`credits_creator`). Rows that predate the author column carry no author_id, so
  # the account that entered them is their only authorship signal.
  def creator_credit_person
    created_by&.person if creator_credited
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
    # Nobody named the author, so the submitter is it (see `credits_creator`).
    creator = creator_credit_person
    return credit_for(creator) if creator
    # No author at all, so it reads as the org's own content.
    missing_author_label
  end

  # Only a credited person links, and only where they aren't hidden — the explicit
  # author, or the submitter on a model that credits them.
  def author_credit_person
    person = primary_author_person || creator_credit_person
    person && !credit_anonymous?(person) ? person : nil
  end

  # A one-way latch: either side can set it, neither can strip it from the other.
  def credit_anonymous?(person)
    person.anonymous_contributions? || author_credit_preference == ANONYMOUS
  end

  # Only an explicit author has a governing profile. A legacy name follows nobody's,
  # and a creator credit reads the live profile with no snapshot taken against it,
  # so neither has a governing person.
  def credit_governing_person
    primary_author_person
  end

  # Snapshot no longer agrees with the governing profile.
  def author_credit_diverged?
    return false if author_credit_preference.blank?
    person = credit_governing_person
    person.present? && author_credit_preference != person.effective_author_credit_preference
  end

  # A named author who opted out of the credit — shown without their name rather than
  # hiding behind "Anonymous". Reads as the same generic label an unattributed record
  # would: "AWBW Staff" for org-produced content, otherwise "AWBW Facilitator".
  def anonymous_author_label
    self.class.unattributed_author_label
  end

  # No author at all, so the content reads as the org's own — "AWBW Staff" for
  # org-produced content, otherwise the facilitator label (see `credits_to_org`).
  def missing_author_label
    self.class.unattributed_author_label
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
    person.name.presence || anonymous_author_label
  end

  class_methods do
    # Content AWBW produces itself credits an unattributed record to "AWBW Staff"
    # rather than the generic facilitator label.
    def credits_to_org
      self.unattributed_author_label = ORG_AUTHOR_LABEL
    end

    # Content whose submitter is its author — the idea forms and workshop logs. An
    # author-less row (anything predating the author column) then credits, links,
    # searches and sorts under the creating account's person, through that person's
    # own credit preference.
    def credits_creator
      self.creator_credited = true
    end

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

    # The people a credit can reach, in display precedence order: the explicit
    # author, then the submitter where the model credits them.
    def credited_person_aliases
      aliases = []
      aliases << CREDITED_AUTHOR_ALIAS if explicit_author?
      aliases << CREATOR_PERSON_ALIAS if creator_credited
      aliases
    end

    def credited_person_join_sql
      joins = []
      if explicit_author?
        joins << "LEFT OUTER JOIN people #{CREDITED_AUTHOR_ALIAS} " \
                 "ON #{CREDITED_AUTHOR_ALIAS}.id = #{table_name}.author_id"
      end
      if creator_credited
        joins << "LEFT OUTER JOIN users creator_account ON creator_account.id = #{table_name}.created_by_id"
        joins << "LEFT OUTER JOIN people #{CREATOR_PERSON_ALIAS} ON #{CREATOR_PERSON_ALIAS}.id = creator_account.person_id"
      end
      joins
    end

    def explicit_author?
      column_names.include?("author_id")
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
      preference = "COALESCE(#{sql_alias}.display_name_preference, 'full_name')"

      by_preference = {
        "full_name" => [ "CONCAT(#{first}, #{last})", "CONCAT(#{last}, #{first})", first, last ],
        "first_name_last_initial" => [ "CONCAT(#{first}, LEFT(#{last}, 1))", first ],
        "first_name_only" => [ first ],
        "last_name_only" => [ last ]
      }.map do |value, expressions|
        "(#{preference} = '#{value}' AND (#{expressions.map { |e| name_like(e) }.join(' OR ')}))"
      end

      # The creator only stands in for an author nobody named, matching what displays.
      outranked = sql_alias == CREATOR_PERSON_ALIAS ? "#{no_person_author_sql} AND " : ""

      "(#{outranked}#{sql_alias}.anonymous_contributions = FALSE AND " \
        "#{not_anonymous_sql} AND (#{by_preference.join(' OR ')}))"
    end

    # A legacy name only displays when no person author outranks it, so it's only
    # searchable then — otherwise the person's profile governs the credit, and the
    # stale column would surface a name that profile hides.
    def legacy_author_name_match_sql(column)
      "(#{no_person_author_sql} AND #{not_anonymous_sql} AND #{name_like(column)})"
    end

    def no_person_author_sql
      explicit_author? ? "#{table_name}.author_id IS NULL" : "TRUE"
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
