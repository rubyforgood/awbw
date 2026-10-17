# Merges a person's or organization's addresses that are one place into a single
# address — repointing their contact methods, billing and affiliation references via
# ModelDeduper#merge — then settles a single primary. Two addresses are one place when
# their AddressNormalizer signatures match ("N Main St" / "North Main Street"), or when
# a less complete copy (no ZIP, no street, …) fits exactly one fuller address.
# Runs in the people and organizations dedupers' after_merge (addresses have no unique
# index, so a merge leaves both records' copies on the keeper) and on the standalone
# Dedupe addresses page.
class AddressDeduper
  # Filled in on the survivor from a merged copy when the survivor has none, so a
  # merge never drops a phone number, a ZIP, or a geocoded district only one copy had.
  CARRIED_COLUMNS = %w[
    street_address zip_code country county district address_type locality
    phone la_city_council_district la_service_planning_area la_supervisorial_district
  ].freeze

  # Columns whose "unknown" value means never recorded.
  UNKNOWN_AS_BLANK_COLUMNS = %w[address_type locality].freeze

  def self.signature(address)
    return unless address

    AddressNormalizer.signature(address)
  end

  # The signature of the primary address to preserve, read before the merge while
  # the two records' addresses can still be told apart: the keeper's own primary,
  # else the deleted record's.
  def self.primary_signature(keep, delete)
    signature(keep.addresses.find_by(primary: true)) ||
      signature(delete.addresses.find_by(primary: true))
  end

  # Merges an owner's duplicate addresses outside a record merge, keeping its current primary.
  def self.merge_duplicates(addressable)
    new(addressable, primary_signature: signature(addressable.addresses.find_by(primary: true))).call
  end

  # The addresses that merge together, each set ordered survivor-first. A set of
  # one is an address with no duplicate. Works from the fullest signature down so
  # a chain of ever-less-complete copies all land on the fullest one.
  def self.matching_sets(addresses)
    sets = addresses.group_by { |address| signature(address) }
    sets.keys.sort_by { |key| -key.count(&:present?) }.each do |key|
      fuller = sets.keys.select { |other| other != key && covers?(other, key) }
      sets[fuller.first].concat(sets.delete(key)) if fuller.one?
    end
    sets.values.map { |set| set.sort_by { |address| keeper_order(address) } }
            .sort_by { |set| keeper_order(set.first) }
  end

  # Every part the partial signature has, the full one has too.
  def self.covers?(full, partial)
    partial.zip(full).all? { |part, full_part| part.blank? || part == full_part }
  end

  # Active before inactive, then the primary, then oldest — so a merge keeps the
  # copy still in use. `Address.active` drives bill-to addresses, an org's program
  # location and the geographic breakdowns, so letting an inactive duplicate win
  # would drop the record out of all of them.
  def self.keeper_order(address)
    [ address.inactive? ? 1 : 0, address.primary? ? 0 : 1, address.id ]
  end

  def initialize(addressable, primary_signature: nil)
    @addressable = addressable
    @primary_signature = primary_signature
  end

  def call
    sets = self.class.matching_sets(@addressable.addresses.reload.to_a)
    primary_set = sets.find { |set| set.any? { |address| self.class.signature(address) == @primary_signature } }

    sets.each do |survivor, *losers|
      losers.each { |loser| merge(loser, into: survivor) }
    end

    settle_primary(sets.map(&:first), primary_set&.first)
  end

  private

  def merge(loser, into:)
    carry_over(loser, into)
    deduper.merge(into, loser)
  end

  def carry_over(loser, survivor)
    filled = CARRIED_COLUMNS.select { |column| missing?(survivor, column) && !missing?(loser, column) }
    return if filled.empty?

    survivor.update!(filled.index_with { |column| loser.public_send(column) })
  end

  def missing?(address, column)
    value = address.public_send(column)
    value.blank? || (UNKNOWN_AS_BLANK_COLUMNS.include?(column) && value.to_s.casecmp?("unknown"))
  end

  def settle_primary(survivors, primary)
    return if @primary_signature.nil?

    survivors.each do |address|
      is_primary = address == primary
      address.update!(primary: is_primary) if address.primary? != is_primary
    end
  end

  def deduper
    @deduper ||= ModelDeduper.new(model_class: Address, logger: Rails.logger, dry_run: false)
  end
end
