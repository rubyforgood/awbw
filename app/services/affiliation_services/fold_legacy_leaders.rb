module AffiliationServices
  # The review behind the Leader affiliations page (index → confirm → perform). A Leader is
  # the old app's Facilitator who is a primary contact, but a row titled Leader counts
  # toward no program status. Each row offers:
  #   * merge  — into its Facilitator twin: the twin turns primary contact on and takes the
  #              Leader row's FileMaker codes and anything attached to it, and the Leader
  #              row goes
  #   * rename — to Facilitator, primary contact on
  #   * end    — rename it and end it today, kept on the record without counting as active
  #   * delete — remove the Leader row outright
  #   * keep   — leave it
  # The suggestion is merge when a Facilitator row has the same dates, rename when none
  # covers its stretch, and keep when one overlaps with different dates — which dates are
  # right is the admin's call. Every change but delete leaves a comment saying it was a Leader.
  class FoldLegacyLeaders
    LEGACY_TITLE = "Leader".freeze
    COMMENT_TOPIC = "Leader cleanup".freeze

    Row = Data.define(:leader, :twin, :same_dates) do
      def key = leader.id.to_s

      def choices = twin ? %w[merge rename end delete keep] : %w[rename end delete keep]

      def suggestion
        return "merge" if same_dates
        return "keep" if twin

        "rename"
      end
    end

    Change = Data.define(:row, :action)

    def self.legacy = Affiliation.where(title: LEGACY_TITLE)

    def rows
      @rows ||= self.class.legacy.includes(:person, :organization).order(:organization_id, :person_id, :id).map { |leader| row_for(leader) }
    end

    def planned_changes(outcome:)
      rows.filter_map do |row|
        action = outcome.to_h[row.key].presence_in(row.choices)
        Change.new(row:, action:) if action && action != "keep"
      end
    end

    def apply(outcome:)
      planned_changes(outcome:).count { |change| perform(change) }
    end

    private

    # The twin is the Facilitator row with the same dates, else the one overlapping the
    # Leader row's stretch with the nearest start.
    def row_for(leader)
      facilitators = Affiliation.facilitators.where(person_id: leader.person_id, organization_id: leader.organization_id).to_a
      same = facilitators.find { |affiliation| affiliation.start_date == leader.start_date && affiliation.end_date == leader.end_date }
      stint = AffiliationStint.of(leader)
      overlapping = facilitators.select { |affiliation| AffiliationStint.of(affiliation).overlap?(stint) }
                                .min_by { |affiliation| leader.start_date && affiliation.start_date ? (affiliation.start_date - leader.start_date).abs : Float::INFINITY }
      Row.new(leader:, twin: same || overlapping, same_dates: same.present?)
    end

    def perform(change)
      leader = change.row.leader
      case change.action
      when "merge" then merge(leader, change.row.twin)
      when "rename" then rename(leader)
      when "end" then end_affiliation(leader)
      when "delete" then leader.destroy!
      end
      true
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotDestroyed
      false
    end

    def merge(leader, twin)
      Affiliation.transaction do
        # Two Leader rows can share a twin, so read it fresh rather than as this row loaded it.
        twin.reload.update!(primary_contact: true, filemaker_code: Affiliation.join_filemaker_codes(twin.filemaker_code, leader.filemaker_code),
                     organization_address_id: twin.organization_address_id || leader.organization_address_id)
        deduper.merge(twin, leader)
        note(twin, "Also recorded as a Leader affiliation (##{leader.id}), merged into this one.")
      end
    end

    def rename(leader)
      leader.update!(title: Affiliation::FACILITATOR_TITLE, primary_contact: true)
      note(leader, "Titled Leader until renamed Facilitator, primary contact.")
    end

    def end_affiliation(leader)
      leader.update!(title: Affiliation::FACILITATOR_TITLE, primary_contact: true, end_date: leader.end_date || Date.current,
                     inactive: true, inactive_supplied: true)
      note(leader, "Titled Leader until renamed Facilitator, primary contact, and ended.")
    end

    def note(affiliation, body)
      affiliation.comments.create!(topic: COMMENT_TOPIC, body:)
    end

    def deduper
      @deduper ||= ModelDeduper.new(model_class: Affiliation, logger: Rails.logger, dry_run: false)
    end
  end
end
