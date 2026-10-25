class AddressesController < ApplicationController
  include AhoyTracking
  include Dedupable
  skip_before_action :preload_current_user_associations, raise: false
  skip_verify_authorized only: :options

  DEDUPE_PURPOSE = "address_dedupe".freeze
  DEDUPE_EDITABLE_COLUMNS = %w[
    street_address city state zip_code country county district address_type locality phone
    la_city_council_district la_service_planning_area la_supervisorial_district
    primary invoice_address inactive
  ].freeze

  def options
    addressable = GlobalID::Locator.locate_signed(params[:addressable_sgid])
    return render json: { addresses: [] } unless addressable&.respond_to?(:addresses)

    addresses = addressable.addresses.active.order(Arel.sql("invoice_address IS NOT TRUE"), id: :desc)
    render json: { addresses: addresses.map { |address| { id: address.id, label: address.decorate.picker_label } } }
  rescue => _e
    render json: { addresses: [] }
  end

  def dedupe_index
    authorize! Address, to: :dedupe?
    @groups = AddressServices::DuplicateFinder.new.groups
  end

  def dedupe_perform_owner
    authorize! Address, to: :dedupe?
    addressable = GlobalID::Locator.locate_signed(params[:addressable_sgid], for: DEDUPE_PURPOSE)
    raise ActiveRecord::RecordNotFound, "Record not found" unless addressable.respond_to?(:addresses)

    merged = merge_addresses(addressable)
    track_event("dedupe.address", { resource_type: addressable.class.name, resource_id: addressable.id, addresses_merged: merged })
    redirect_to dedupe_index_addresses_path, notice: "Merged #{helpers.pluralize(merged, "duplicate address")}."
  rescue ActionPolicy::Unauthorized
    raise
  rescue StandardError => e
    redirect_to dedupe_index_addresses_path, alert: "Error merging addresses: #{e.message}"
  end

  def dedupe_perform_all
    authorize! Address, to: :dedupe?
    MergeDuplicateAddressesJob.perform_later(current_user)

    track_event("dedupe.address_all", {})
    redirect_to dedupe_index_addresses_path,
      notice: "Merging duplicate addresses in the background. Refresh in a few minutes to see what's left."
  end

  private

  def dedupe_config
    {
      model_class: Address,
      editable_columns: DEDUPE_EDITABLE_COLUMNS,
      record_path: ->(address) { edit_polymorphic_path(address.addressable) },
      merge_blocks: ->(keep, delete) {
        next [] if keep.addressable_type == delete.addressable_type && keep.addressable_id == delete.addressable_id

        [ "These addresses belong to different records, so they can't merge." ]
      },
      merge_outcomes: ->(keep, delete) {
        moved = { delete: "Moves to the kept address", keep: "Fills in from the deleted copy" }
        fields = AddressDeduper.carried_values(keep, delete).keys.index_with { moved }
        fields["primary"] = { delete: "Moves to the kept address", keep: "Becomes the primary address" } if delete.primary? && !keep.primary?
        { fields: fields }
      },
      merge_keeper: ->(keep, delete) {
        keep.assign_attributes(AddressDeduper.carried_values(keep, delete))
        keep.primary = true if delete.primary?
      }
    }
  end

  def dedupe_return
    anchor = params[:anchor_id].presence
    { label: "Back to dedupe addresses", path: dedupe_index_addresses_path(anchor: anchor), params: { anchor_id: anchor }.compact }
  end

  def merge_addresses(addressable)
    ActiveRecord::Base.transaction do
      before = addressable.addresses.count
      AddressDeduper.merge_duplicates(addressable)
      before - addressable.addresses.count
    end
  end
end
