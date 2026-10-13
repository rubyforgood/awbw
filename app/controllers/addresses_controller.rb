class AddressesController < ApplicationController
  skip_before_action :preload_current_user_associations, raise: false
  skip_verify_authorized

  def options
    addressable = GlobalID::Locator.locate_signed(params[:addressable_sgid])
    return render json: { addresses: [] } unless addressable&.respond_to?(:addresses)

    addresses = addressable.addresses.active.order(id: :desc)
    render json: { addresses: addresses.map { |address| { id: address.id, label: address.name } } }
  rescue => _e
    render json: { addresses: [] }
  end
end
