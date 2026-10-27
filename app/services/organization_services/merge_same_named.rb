module OrganizationServices
  # Merges portal organizations that are one place under several names (ADR-0008), before the
  # FileMaker import reads them: the old app's audience versions ("… Women's", "… Combined") and
  # newer twins share FilemakerNames.same_name_key. The keeper — most affiliations, then oldest —
  # takes each other one, the way the admin deduper merges, unless both have known cities, none
  # shared, and no FileMaker parent in common (a retired duplicate counts as its original): those
  # are different places sharing a name. Cities come from portal addresses, the FileMaker project's
  # City, and FileMaker addresses. The keeper then drops its audience word unless another
  # organization holds the shorter name.
  #
  # Activity is tagged merge_run, so fm:undo_import never half-reverses a merge.
  class MergeSameNamed
    include FilemakerValues

    OUTCOMES = %i[merged kept_apart renamed failed].freeze
    LISTED_OUTCOMES = OUTCOMES
    FILLED_FIELDS = %w[
      email website_url description mission_vision_values notes tax_id organization_type
      organization_type_other organization_status_id windows_type_id location_id parent_id
    ].freeze

    attr_reader :results

    def initialize(progress: nil, run: nil, **)
      @progress = progress
      @run = run
      @results = OUTCOMES.index_with { [] }
    end

    def call
      @tracker = Ahoy::Tracker.new
      @deduper = ModelDeduper.new(model_class: Organization, logger: Rails.logger, dry_run: false)
      @project_parents = FmProject.pluck(:fm_id, Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(data, '$.OrgID'))")).to_h
      @fm_organization_ids = FmOrganization.pluck(:fm_id).to_set
      @fm_cities = fm_cities
      groups = Organization.pluck(:id, :name).group_by { |_id, name| FilemakerNames.same_name_key(name) }
                           .reject { |key, rows| key.blank? || rows.one? }.values
      groups.each_with_index do |rows, index|
        in_transaction { merge_group(rows.map(&:first)) }
        @progress&.call(index + 1)
      end
      self
    end

    private

    def in_transaction(&)
      ActiveRecord::Base.transaction(requires_new: true) do
        Analytics::LifecycleBuffer.tagging(@run ? { merge_run: @run } : {}, &)
        Analytics::LifecycleBuffer.flush_to(@tracker)
      end
    end

    def merge_group(ids)
      organizations = Organization.where(id: ids).includes(:addresses).to_a
      affiliations = Affiliation.where(organization_id: ids).group(:organization_id).count
      keeper = organizations.max_by { |organization| [ affiliations[organization.id].to_i, -organization.id ] }
      evidence = organizations.index_with { |organization| [ cities(organization), parents(organization) ] }
      kept_apart = []
      (organizations - [ keeper ]).sort_by(&:id).each do |other|
        next kept_apart << other if different_places?(evidence[keeper], evidence[other], keeper, other)

        merge(keeper, other)
      end
      rename(keeper)
    end

    def different_places?((keeper_cities, keeper_parents), (other_cities, other_parents), keeper, other)
      return false if keeper_cities.empty? || other_cities.empty?
      return false if keeper_cities.keys.intersect?(other_cities.keys) || keeper_parents.intersect?(other_parents)

      record(:kept_apart, "##{other.id} #{other.name} (#{other_cities.values.join(", ")}) kept apart from " \
                          "##{keeper.id} #{keeper.name} (#{keeper_cities.values.join(", ")}): different cities, no FileMaker parent in common")
      true
    end

    # The admin deduper's merge: codes joined, blanks filled, every record moved, then the
    # addresses, phones and affiliations the move doubled folded together.
    def merge(keeper, other)
      label = "##{other.id} #{other.name} into ##{keeper.id} #{keeper.name}"
      snapshot = other.attributes
      address_signature = AddressDeduper.primary_signature(keeper, other)
      contact_signatures = ContactMethodDeduper.primary_signatures(keeper, other)
      keeper.filemaker_code = Organization.join_filemaker_codes(keeper.filemaker_code, other.filemaker_code)
      FILLED_FIELDS.each { |field| keeper[field] = other[field] if keeper[field].blank? && other[field].present? }
      keeper.parent_id = nil if [ keeper.id, other.id ].include?(keeper.parent_id)
      keeper.school ||= other.school
      ActiveRecord::Base.transaction(requires_new: true) do
        @deduper.merge(keeper, other)
        AddressDeduper.new(keeper, primary_signature: address_signature).call
        ContactMethodDeduper.new(keeper, primary_signatures: contact_signatures).call
        AffiliationDeduper.new(keeper).call
        keeper.save!
      end
      @tracker.track("dedupe.organization", { resource_type: "Organization", resource_id: keeper.id, deleted_record: snapshot,
                                              kept_record: { id: keeper.id, name: keeper.name }, merge_run: @run }.compact)
      record(:merged, label)
    rescue ActiveRecord::ActiveRecordError, RuntimeError => e
      keeper.restore_attributes
      record(:failed, "#{label}: #{e.message}")
    end

    def rename(keeper)
      name = FilemakerNames.without_audience(keeper.name)
      return if name == keeper.name || Organization.where.not(id: keeper.id).exists?(name:)

      was = keeper.name
      return record(:failed, "##{keeper.id} #{was}: rename to #{name} — #{keeper.errors.full_messages.to_sentence}") unless keeper.update(name:)

      record(:renamed, "##{keeper.id} #{was} → #{name}")
    end

    # Each city by its comparison key, keeping the spelling first seen for the report.
    def cities(organization)
      portal = organization.addresses.map(&:city)
      fm = organization.filemaker_codes.flat_map { |code| @fm_cities[code] }
      (portal + fm).each_with_object({}) do |city, found|
        key = AddressNormalizer.city(city).presence
        found[key] ||= city.squish if key
      end
    end

    def parents(organization)
      organization.filemaker_codes.filter_map do |code|
        parent = @fm_organization_ids.include?(code) ? code : @project_parents[code].presence
        parent && (duplicate_of(parent) || parent)
      end.to_set
    end

    def fm_cities
      cities = Hash.new { |hash, code| hash[code] = [] }
      FmProject.pluck(:fm_id, Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(data, '$.City'))")).each { |code, city| cities[code] << city }
      FmAddress.pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(data, '$.OrgID'))"), Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(data, '$.AddrsCity'))"))
               .each { |code, city| cities[code] << city if code.present? }
      cities
    end

    def record(outcome, message)
      @results[outcome] << message
    end
  end
end
