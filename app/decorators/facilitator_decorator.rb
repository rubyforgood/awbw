class FacilitatorDecorator < Draper::Decorator
  delegate_all

 DISPLAY_FIELDS = {
    "First name" => :first_name,
    "Last name" => :last_name,
    "Primary email address" => :primary_email_address,
    "Primary email type" => :primary_email_address_type,
    "Street address" => :street_address,
    "City" => :city,
    "State" => :state,
    "ZIP" => :zip,
    "Country" => :country,
    "Mailing address type" => :mailing_address_type,
    "Phone number" => :phone_number,
    "Phone number type" => :phone_number_type
  }

  def display_fields
    DISPLAY_FIELDS.map do |label, method|
      { label: label, value: object.send(method) }
    end
  end
end
