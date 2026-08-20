class BulkInviteEmailJob < ApplicationJob
  queue_as :default

  def perform(user_id, sender_id: nil)
    user = User.find(user_id)
    sender = User.find_by(id: sender_id) if sender_id
    user.send_confirmation_instructions(sender: sender)
  end
end
