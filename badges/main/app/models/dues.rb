module Dues
  # TODO enable for production when full dues feature is complete
  def self.enabled?
    !Rails.env.production?
  end

  TIME_ZONE = "Pacific Time (US & Canada)".freeze

  ANNUAL_COST_CENTS = ENV.fetch("ANNUAL_DUES_CENTS", 2500).to_i
  GRACE_PERIOD_DAYS = ENV.fetch("ANNUAL_DUES_GRACE_PERIOD_DAYS", 30).to_i
  RENEWAL_WINDOW_DAYS = ENV.fetch("ANNUAL_DUES_RENEWAL_WINDOW_DAYS", 30).to_i
end
