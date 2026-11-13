class ApplicationMailer < ActionMailer::Base
  helper ApplicationHelper
  include Rails.application.routes.url_helpers

  FROM_NAME = "AWBW Programs".freeze
  FALLBACK_TIME_ZONE = "Pacific Time (US & Canada)".freeze

  # Wraps the generic mailbox with a friendly display name so recipients see
  # "AWBW Programs" rather than the bare "programs" local part.
  def self.sender(address = Setting.programs_email)
    %("#{FROM_NAME}" <#{address}>)
  end

  # Procs, not values: a bare call here would freeze the address at class load,
  # before a spec or a reloaded environment can change it.
  default from: -> { self.class.sender }
  default reply_to: -> { Setting.programs_email }

  layout "mailer"

  private

  # Mail renders in a background job with no viewer, so times follow the recipient's own setting.
  def recipient_time_zone(person)
    person&.user&.time_zone.presence || FALLBACK_TIME_ZONE
  end
end
