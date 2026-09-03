class ApplicationMailer < ActionMailer::Base
  helper ApplicationHelper
  include Rails.application.routes.url_helpers

  FROM_NAME = "AWBW Programs".freeze

  # Wraps the generic mailbox with a friendly display name so recipients see
  # "AWBW Programs" rather than the bare "programs" local part.
  def self.sender(address = ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"))
    %("#{FROM_NAME}" <#{address}>)
  end

  default from: sender
  default reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")

  layout "mailer"
end
