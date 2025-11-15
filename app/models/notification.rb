class Notification < ApplicationRecord
  belongs_to :noticeable, polymorphic: true
  after_save :send_notice

  enum :notification_type, { created: 0, updated: 1 }
  attr_accessor :fields_changed

  def send_notice
    NotificationMailer
      .report_notification(self)
      .deliver_now
  end
end
