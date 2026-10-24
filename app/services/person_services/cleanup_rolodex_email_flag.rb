module PersonServices
  # Repairs the people fm:import_people wrote while it read the Rolodex EmailPrimary flag
  # ("1" primary, "2" secondary) as an address. For each flagged row's people:
  #   * comments_deleted / comments_trimmed — the flag drops out of the import's
  #     "couldn't take" comment, and a comment left quoting nothing goes
  #   * moved_to_email_2 — a person the import created from a row flagged 2 has its
  #     address moved to email_2, with a placeholder primary when a same-name person
  #     already holds no email
  #   * placeholders_cleared — a person the import created from a row holding only the
  #     flag loses the placeholder email the flag earned them
  #   * possible_duplicates — that person shares a name with someone who has no email,
  #     whom the row should have linked; left for review
  #   * kept — a flag-2 person whose email can't move (a login, or a second email already)
  # People the import only linked keep their emails: those were the portal's, not the row's.
  class CleanupRolodexEmailFlag
    OUTCOMES = %i[comments_deleted comments_trimmed moved_to_email_2 placeholders_cleared possible_duplicates kept].freeze
    IMPORT_SOURCE = "fm_import_people"

    attr_reader :results

    def initialize(scope: FmRolodex.all)
      @scope = scope
      @results = OUTCOMES.index_with { [] }
    end

    def call
      flagged.find_each do |rolodex|
        Person.with_filemaker_code(rolodex.fm_id).each { |person| clean(person, rolodex) }
      end
      Analytics::LifecycleBuffer.flush_to(Ahoy::Tracker.new)
      self
    end

    private

    def flagged
      @scope.where("JSON_CONTAINS_PATH(data, 'one', ?)", "$.#{ImportFromRolodex::EMAIL_FLAG_FIELD}")
    end

    def clean(person, rolodex)
      flag = rolodex.data[ImportFromRolodex::EMAIL_FLAG_FIELD].to_s.strip
      label = "#{rolodex.fm_id} → ##{person.id}"
      # Untouched, so a comment fix doesn't make the person look edited to fm:undo_import_people.
      Person.no_touching { clean_comments(person, rolodex.fm_id, flag, label) }
      return unless imported_person_ids.include?(person.id)

      address = rolodex.data["EMail"].to_s.strip
      return move_to_email_2(person, label) if flag == ImportFromRolodex::SECONDARY_EMAIL_FLAG && address.present?

      clear_placeholder(person, label) if address.empty?
    end

    def clean_comments(person, fm_id, flag, label)
      heading = ImportFromRolodex.invalid_email_heading(fm_id)
      flag_line = "“#{flag}”"
      person.comments.where("body LIKE ?", "#{Comment.sanitize_sql_like(heading)}%").find_each do |comment|
        values = comment.body.split("\n").drop(1)
        next unless values.include?(flag_line)

        kept = values - [ flag_line ]
        if kept.empty?
          comment.destroy!
          @results[:comments_deleted] << label
        else
          comment.update!(body: [ heading, *kept ].join("\n"))
          @results[:comments_trimmed] << label
        end
      end
    end

    def move_to_email_2(person, label)
      return unless person.email_on_file
      return @results[:kept] << "#{label}: has a login" if person.user
      return @results[:kept] << "#{label}: already has a second email" if person.email_2.present?

      person.email_2, person.email_2_type = person.email, person.email_type
      person.email = person.email_type = nil
      person.email = person.next_free_placeholder_email if same_name(person).where(email: [ nil, "" ]).exists?
      return @results[:kept] << "#{label}: #{person.errors.full_messages.to_sentence}" unless person.save

      @results[:moved_to_email_2] << label
    end

    def clear_placeholder(person, label)
      return unless person.placeholder_email?

      twins = same_name(person).where(email: [ nil, "" ]).pluck(:id)
      return @results[:possible_duplicates] << "#{label}: same name as #{twins.map { |id| "##{id}" }.join(", ")}" if twins.any?
      return @results[:kept] << "#{label}: #{person.errors.full_messages.to_sentence}" unless person.update(email: nil)

      @results[:placeholders_cleared] << label
    end

    def same_name(person)
      Person.where("LOWER(first_name) = ? AND LOWER(last_name) = ?", person.first_name.downcase, person.last_name.downcase)
            .where.not(id: person.id)
    end

    def imported_person_ids
      @imported_person_ids ||= Ahoy::Event.where(name: "create.person")
                                          .where("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.source')) = ?", IMPORT_SOURCE)
                                          .pluck(Arel.sql("JSON_EXTRACT(properties, '$.resource_id')"))
                                          .map(&:to_i).to_set
    end
  end
end
