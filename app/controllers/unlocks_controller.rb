class UnlocksController < Devise::UnlocksController
  include EmailDeliveryRescuable
end
