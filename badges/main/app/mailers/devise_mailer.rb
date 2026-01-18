class DeviseMailer < Devise::Mailer
  helper ApplicationHelper
  include Rails.application.routes.url_helpers
  before_action :set_branding

  default from: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")
  default reply_to: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org")

  def default_url_options
    Rails.application.config.action_mailer.default_url_options
  end

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
