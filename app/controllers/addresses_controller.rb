class AddressesController < ApplicationController
  include AhoyTracking
  skip_before_action :preload_current_user_associations, raise: false
  skip_verify_authorized only: :options

  DEDUPE_PURPOSE = "address_dedupe".freeze

  def options
    addressable = GlobalID::Locator.locate_signed(params[:addressable_sgid])
    return render json: { addresses: [] } unless addressable&.respond_to?(:addresses)

    addresses = addressable.addresses.active.order(Arel.sql("invoice_address IS NULL"), id: :desc)
    render json: { addresses: addresses.map { |address| { id: address.id, label: address.decorate.picker_label } } }
  rescue => _e
    render json: { addresses: [] }
  end

  def dedupe_index
    authorize! :dedupe, to: :dedupe?
    @groups = AddressServices::DuplicateFinder.new.groups
  end

  def dedupe_perform
    authorize! :dedupe, to: :dedupe?
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

  private

  def merge_addresses(addressable)
    ActiveRecord::Base.transaction do
      before = addressable.addresses.count
      AddressDeduper.merge_duplicates(addressable)
      before - addressable.addresses.count
    end
  end
end
