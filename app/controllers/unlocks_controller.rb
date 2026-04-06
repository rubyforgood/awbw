class UnlocksController < Devise::UnlocksController
  rescue_from(*EmailDeliveryErrorHandler::ERRORS) { |e| EmailDeliveryErrorHandler.handle(e, self) }
end
