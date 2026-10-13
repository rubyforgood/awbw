# Stripe caps each metadata value at 500 characters
module StripeMetadata
  extend ActiveSupport::Concern

  STRIPE_METADATA_VALUE_LIMIT = 500

  private

  def stripe_metadata(attributes)
    attributes.transform_values do |value|
      string = value.to_s
      string.length > STRIPE_METADATA_VALUE_LIMIT ? string.truncate(STRIPE_METADATA_VALUE_LIMIT) : value
    end
  end
end
