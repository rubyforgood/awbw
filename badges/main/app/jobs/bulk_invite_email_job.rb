class BulkInviteEmailJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    user.send_confirmation_instructions
  end
end
