class Notification < ApplicationRecord
  belongs_to :noticeable, polymorphic: true
  after_save :send_notice

  enum notification_type: [:created, :updated]
  attr_accessor :fields_changed

  def send_notice
    Admins::NotificationMailer
      .email(self)
      .deliver_now
  end
end
