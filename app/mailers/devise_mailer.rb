class DeviseMailer < Devise::Mailer
  helper ApplicationHelper
<<<<<<< HEAD
  include Rails.application.routes.url_helpers
  before_action :set_branding

  default from: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
  default reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")

  def default_url_options
    Rails.application.config.action_mailer.default_url_options
  end
=======

  before_action :set_branding

  default from: ENV.fetch(
    "REPLY_TO_EMAIL",
    "no-reply@awbw.org"
  )

  default reply_to: ENV.fetch(
    "REPLY_TO_EMAIL",
    "programs@awbw.org"
  )
>>>>>>> 5dfd1ed1 (Add local DeviseMailer class to override defaults and add explicit from and reply_to, and pass @organization_name to views)

  protected

  def set_branding
    @organization_name = ENV.fetch("ORGANIZATION_NAME", "Our organization")
  end

  def headers_for(action, opts)
    headers = super
    headers[:subject] = I18n.t(
      "devise.mailer.#{action}.subject",
      organization_name: @organization_name
    )
    headers
  end
end
