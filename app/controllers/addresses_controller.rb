class AddressesController < ApplicationController
  skip_before_action :preload_current_user_associations, raise: false
  skip_verify_authorized

  def lookup
    addressable = GlobalID::Locator.locate_signed(params[:addressable_id])
    return head :not_found unless addressable

    address = addressable.addresses.active.first
    if address
      formatted = [address.street_address, "#{address.city}, #{[address.state, address.zip_code].compact.join(' ')}"].compact.join("\n")
      render json: { address: formatted }
    else
      head :not_found
    end
  rescue => _e
    head :bad_request
  end
end
