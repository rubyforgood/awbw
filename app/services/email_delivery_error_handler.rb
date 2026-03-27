class EmailDeliveryErrorHandler
  ERRORS = [
    OpenSSL::SSL::SSLError,
    Net::SMTPError,
    Errno::ECONNRESET
  ].freeze

  def self.handle(exception, controller)
    Rails.logger.error("Email delivery failed: #{exception.class} - #{exception.message}")
    controller.flash[:alert] = "Email failed to send. Please try again in a few minutes."
    controller.redirect_back(fallback_location: controller.root_path)
  end
end
