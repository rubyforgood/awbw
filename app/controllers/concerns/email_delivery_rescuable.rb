module EmailDeliveryRescuable
  extend ActiveSupport::Concern

  EMAIL_DELIVERY_ERRORS = [
    OpenSSL::SSL::SSLError,
    Net::SMTPError,
    Errno::ECONNRESET
  ].freeze

  included do
    rescue_from(*EMAIL_DELIVERY_ERRORS) do |exception|
      Rails.logger.error("Email delivery failed: #{exception.class} - #{exception.message}")
      flash[:alert] = "Email failed to send. Please try again in a few minutes."
      redirect_back(fallback_location: root_path)
    end
  end
end
