# Merges a person's or organization's identical affiliations — same person,
# organization, title, dates, and status — into one, moving the copies' comments and
# references onto the survivor via ModelDeduper#merge. A record merge moves the
# deleted record's affiliations across with update_all, so copies land that
# Affiliation#skip_if_duplicate would have refused. Runs in the people and
# organizations dedupers' after_merge.
class AffiliationDeduper
  def initialize(owner)
    @owner = owner
  end

  def call
    @owner.affiliations.reload.group_by { |affiliation| identity(affiliation) }.each_value do |set|
      next if set.one?

      survivor, *losers = set.sort_by { |affiliation| keeper_order(affiliation) }
      merge(losers, into: survivor)
    end
  end

  private

  def identity(affiliation)
    [
      affiliation.person_id, affiliation.organization_id, affiliation.title.to_s.strip,
      affiliation.start_date, affiliation.end_date, affiliation.inactive
    ]
  end

  # The copy a registration created first (registration reconciliation tracks it), then the oldest.
  def keeper_order(affiliation)
    [ affiliation.event_registration_id ? 0 : 1, affiliation.id ]
  end

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
