class ApplicationMailer < ActionMailer::Base
  helper ApplicationHelper
  include Rails.application.routes.url_helpers

  default from: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
  default reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")

  layout "mailer"
end
