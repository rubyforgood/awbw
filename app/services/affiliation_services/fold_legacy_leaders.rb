module AffiliationServices
  # Folds the old app's "Leader" affiliations into Facilitator ones. A Leader is a
  # Facilitator who is a primary contact — the shape the January 2026 conversion gave most
  # of them, beside the Leader row it left behind — but a row titled Leader counts toward
  # no program status. Each row:
  #   * with a Facilitator twin over the same dates merges into it: the twin turns primary
  #     contact on, takes the Leader row's FileMaker codes and anything attached to it, and
  #     the Leader row goes
  #   * with no Facilitator row in its stretch becomes one, primary contact on
  #   * overlapping a Facilitator row with different dates is left for an admin, since which
  #     dates are right is a call made per row
  # Either fold leaves a comment on the Facilitator row saying it was a Leader. Returns how
  # many it folded.
  class FoldLegacyLeaders
    LEGACY_TITLE = "Leader".freeze
    COMMENT_TOPIC = "Leader cleanup".freeze

    def self.legacy = Affiliation.where(title: LEGACY_TITLE)

    def call
      self.class.legacy.to_a.count { |leader| fold(leader) }
    end

    private

    def fold(leader)
      facilitators = Affiliation.facilitators.where(person_id: leader.person_id, organization_id: leader.organization_id).to_a
      twin = facilitators.find { |affiliation| affiliation.start_date == leader.start_date && affiliation.end_date == leader.end_date }
      return merge(leader, twin) if twin

      stint = AffiliationStint.of(leader)
      return false if facilitators.any? { |affiliation| AffiliationStint.of(affiliation).overlap?(stint) }

      rename(leader)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
      false
    end

    def merge(leader, twin)
      Affiliation.transaction do
        twin.update!(primary_contact: true, filemaker_code: Affiliation.join_filemaker_codes(twin.filemaker_code, leader.filemaker_code),
                     organization_address_id: twin.organization_address_id || leader.organization_address_id)
        deduper.merge(twin, leader)
        note(twin, "Also recorded as a Leader affiliation (##{leader.id}), merged into this one.")
      end
      true
    end

    def rename(leader)
      leader.update!(title: Affiliation::FACILITATOR_TITLE, primary_contact: true)
      note(leader, "Titled Leader until renamed Facilitator, primary contact.")
      true
    end

    def note(affiliation, body)
      affiliation.comments.create!(topic: COMMENT_TOPIC, body:)
    end

    def deduper
      @deduper ||= ModelDeduper.new(model_class: Affiliation, logger: Rails.logger, dry_run: false)
    end
  end
end
