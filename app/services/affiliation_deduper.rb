# Merges a person's or organization's identical affiliations — same person,
# organization, title, dates, and status — into one, moving the copies' comments and
# references onto the survivor via ModelDeduper#merge. A record merge moves the
# deleted record's affiliations across with update_all, so copies land that
# Affiliation#skip_if_duplicate would have refused. Runs in the people and
# organizations dedupers' after_merge, and on the standalone Dedupe affiliations page.
class AffiliationDeduper
  # The sets of identical affiliations, each ordered survivor-first. Sets of one are left out.
  def self.duplicate_sets(affiliations)
    affiliations.group_by { |affiliation| identity(affiliation) }.values
      .reject(&:one?)
      .map { |set| set.sort_by { |affiliation| keeper_order(affiliation) } }
  end

  def self.identity(affiliation)
    [
      affiliation.person_id, affiliation.organization_id, affiliation.type,
      affiliation.title.to_s.strip, affiliation.start_date, affiliation.end_date, affiliation.inactive
    ]
  end

  # The copy a registration created first (registration reconciliation tracks it), then the oldest.
  def self.keeper_order(affiliation)
    [ affiliation.event_registration_id ? 0 : 1, affiliation.id ]
  end

  def initialize(owner)
    @owner = owner
  end

  def call
    self.class.duplicate_sets(@owner.affiliations.reload.to_a).each do |survivor, *losers|
      merge(losers, into: survivor)
    end
  end

  private

  # Merges before saving the survivor: skip_if_duplicate aborts its save while an identical copy exists.
  def merge(losers, into:)
    carried = carried_attributes(into, losers)
    losers.each { |loser| deduper.merge(into, loser) }
    into.reload.update!(carried)
  end

  def carried_attributes(survivor, losers)
    {
      event_registration_id: survivor.event_registration_id || losers.filter_map(&:event_registration_id).first,
      organization_address_id: survivor.organization_address_id || losers.filter_map(&:organization_address_id).first,
      primary_contact: survivor.primary_contact || losers.any?(&:primary_contact),
      filemaker_code: Affiliation.join_filemaker_codes(survivor.filemaker_code, *losers.map(&:filemaker_code))
    }
  end

  def deduper
    @deduper ||= ModelDeduper.new(model_class: Affiliation, logger: Rails.logger, dry_run: false)
  end
end
