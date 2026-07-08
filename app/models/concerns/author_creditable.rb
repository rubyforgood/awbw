module AuthorCreditable
  extend ActiveSupport::Concern

  AUTHOR_CREDIT_PREFERENCES = %w[full_name first_name_last_initial first_name_only last_name_only anonymous].freeze

  IDEA_FORM_OPTIONS = {
    "I would like my full name published with the story" => "full_name",
    "I would like my first name and last initial published" => "first_name_last_initial",
    "I would like only my first name published" => "first_name_only",
    "I would like only my last name published" => "last_name_only",
    "I do not want my name published with my story" => "anonymous"
  }.freeze

  ADMIN_FORM_OPTIONS = {
    "Full name" => "full_name",
    "First name, last initial" => "first_name_last_initial",
    "First name only" => "first_name_only",
    "Last name only" => "last_name_only",
    "Anonymous" => "anonymous"
  }.freeze

  included do
    # Default to the full name in the UI (new records and unset form fields).
    # Existing rows with no preference are treated as "full_name" — at read time
    # by `author_credit` and, on their next save, normalized by the callback below.
    # There is no data backfill.
    attribute :author_credit_preference, :string, default: "full_name"
    before_validation :default_author_credit_preference
    validates :author_credit_preference, inclusion: { in: AUTHOR_CREDIT_PREFERENCES }
  end

  # The linkable credited person, in precedence order: the explicit/legacy author
  # person, otherwise the creating user's person. This is what views link to.
  def author_person
    primary_author_person || created_by&.person
  end

  # The credited author person that is *not* the creator fallback — the explicit
  # author. Overridden by models with an additional legacy person tier (e.g.
  # CommunityNews folds in its legacy_author_user's person).
  def primary_author_person
    author if respond_to?(:author)
  end

  # A legacy free-text author name (no linkable person), ranked between the
  # explicit author and the creator. Overridden by models that have one
  # (Workshop, Resource).
  def legacy_author_name_text
    nil
  end

  # Display string for the credited author, honoring the credit preference.
  # Precedence: an explicit "anonymous" preference always renders "Anonymous";
  # then the primary author person, then the legacy free-text name, then the
  # creating user's person, then `missing_author_label`.
  def author_credit
    return "Anonymous" if author_credit_preference == "anonymous"
    person = primary_author_person
    return format_person_credit(person) if person
    return legacy_author_name_text if legacy_author_name_text.present?
    format_person_credit(created_by&.person)
  end

  # The person the credit should link to, or nil when the credit must not resolve
  # to a profile. Only an explicit/legacy author links: a credit that falls back
  # to the creating user's person is shown as plain text, because that person
  # never declared authorship (and the record isn't listed on their profile
  # either). Anonymous never links.
  def author_credit_person
    return nil if author_credit_preference == "anonymous"
    primary_author_person
  end

  # Shown when there is no credited person or legacy name. Overridable per model
  # (e.g. Workshop shows "Facilitator").
  def missing_author_label
    "Anonymous"
  end

  # Treat an unset preference as "full_name" so legacy rows normalize on save
  # without a bulk backfill.
  def default_author_credit_preference
    self.author_credit_preference = "full_name" if author_credit_preference.blank?
  end

  # Formats a person's name per the credit preference, falling back to
  # `missing_author_label` when the person or the requested name part is missing.
  private def format_person_credit(person)
    case author_credit_preference
    when "first_name_last_initial"
      first = person&.first_name
      first.present? ? "#{first} #{person.last_name&.first}." : missing_author_label
    when "first_name_only"
      person&.first_name.presence || missing_author_label
    when "last_name_only"
      person&.last_name.presence || missing_author_label
    else # full_name — the default, and the fallback for any unknown value
      person&.full_name.presence || missing_author_label
    end
  end

  class_methods do
    # Legacy free-text columns (fully qualified, e.g. "resources.legacy_author_name")
    # that also hold an author's name. Overridden per model that has one.
    def legacy_author_name_columns
      []
    end

    # Legacy "belongs_to a User" columns whose person should also be credited,
    # as [ foreign_key_column, sql_alias ] pairs. Overridden per model (e.g.
    # CommunityNews folds in its legacy_author_user). Alias must be SQL-safe.
    def legacy_credited_user_columns
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

      clauses = credited_person_aliases.flat_map { |a| person_name_match_clauses(a) }
      clauses += legacy_author_name_columns.map { |col| "LOWER(REPLACE(#{col}, ' ', '')) LIKE :name" }
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
      legacy_credited_user_columns.each { |_, sql_alias| aliases << sql_alias }
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
      legacy_credited_user_columns.each do |fk_column, sql_alias|
        sql << "LEFT OUTER JOIN users #{sql_alias}_user ON #{sql_alias}_user.id = #{table_name}.#{fk_column}"
        sql << "LEFT OUTER JOIN people #{sql_alias} ON #{sql_alias}.id = #{sql_alias}_user.person_id"
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

    def person_name_match_clauses(sql_alias)
      [
        "LOWER(REPLACE(CONCAT(#{sql_alias}.first_name, #{sql_alias}.last_name), ' ', '')) LIKE :name",
        "LOWER(REPLACE(CONCAT(#{sql_alias}.last_name, #{sql_alias}.first_name), ' ', '')) LIKE :name",
        "LOWER(REPLACE(#{sql_alias}.first_name, ' ', '')) LIKE :name",
        "LOWER(REPLACE(#{sql_alias}.last_name, ' ', '')) LIKE :name"
      ]
    end
  end
end
