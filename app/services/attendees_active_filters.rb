# Human-readable descriptors for the attendees index's "drill-in" filters — the
# params that narrow the roster but have no field in the visible filter form
# (they arrive from a chart-row click, the participation summary, or a shared
# link). The index surfaces each as a removable chip so an admin can see and
# clear a filter that would otherwise silently shrink the list. Params that
# already have their own visible control in events/_attendees_search (contact_info,
# event, year, sector, program status, affiliation status, and the registration-level
# filters shared with the roster — payment method, scholarship, funder name, CE
# status, user account, topic subscription, city, state, county, comment status and
# text) are intentionally omitted — the control itself already shows them. That's why
# the CE pie's drill-ins use ce_status rather than a chip-only param.
class AttendeesActiveFilters
  # Drill-in params in chip display order. Each renders via #label_for. Keep this
  # in step with every param the attendees index narrows on: a param the index
  # honours but this list omits narrows the page silently AND is dropped by the
  # filter form's hidden fields on the next change, since both read this list.
  CHIP_PARAMS = %w[
    registrant_ids organization_id org_city age_group life_experience setting
    country school_district payment_status funder
  ].freeze
  # The roster has no filter form at all, so every drill-in it accepts needs a
  # chip — including the two the index leaves out because it has controls for them.
  ROSTER_CHIP_PARAMS = %w[ registrant_ids sector state ].freeze

  def initialize(params, chip_params: CHIP_PARAMS)
    @params = params
    @chip_params = chip_params
  end

  # [ { param: "age_group", label: "Age group: Teens (13-17)" }, ... ] in
  # CHIP_PARAMS order; empty when no drill-in filter is applied. A param whose
  # referenced record no longer exists is dropped rather than shown label-less.
  def chips
    @chip_params.filter_map do |param|
      value = @params[param]
      next if value.blank?
      label = label_for(param, value)
      { param: param, label: label } if label.present?
    end
  end

  private

  def label_for(param, value)
    case param
    when "registrant_ids" then "#{value.to_s.split("-").size} selected people"
    when "sector" then record_label("Sector", Sector, value)
    when "state" then "State: #{value}"
    when "organization_id" then record_label("Organization", Organization, value)
    when "org_city" then "Org city: #{value}"
    when "age_group" then record_label("Age group", Category, value)
    when "life_experience" then record_label("Life experience", Category, value)
    when "setting" then record_label("Setting", Category, value)
    when "country" then "Country: #{value}"
    when "school_district" then "School district: #{value}"
    when "payment_status" then option_label("Payment", EventRegistration::PAYMENT_STATUS_FILTER_OPTIONS, value)
    when "funder" then option_label("Funding", EventRegistration::FUNDER_FILTER_OPTIONS, value)
    end
  end

  def record_label(prefix, model, id)
    name = model.where(id: id).pick(:name)
    "#{prefix}: #{name}" if name
  end

  # Label from the filter's own option list, so the chip and the select can't word
  # the same value differently. Nil for a value the list doesn't offer — the
  # matching scope treats those as a no-op, so there's nothing to chip.
  def option_label(prefix, options, value)
    label = options.rassoc(value)&.first
    "#{prefix}: #{label}" if label
  end
end
