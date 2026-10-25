module Admin
  class HomeController < ApplicationController
    include AdminCardsHelper

    DATA_HEALTH_BADGE_TITLE = "Data checks only. Possible duplicates and author credit are counted separately on the Data health page.".freeze

    def index
      authorize! :home, to: :index?

      @system_cards          = system_cards
      @user_content_cards    = user_content_cards
      @reference_cards       = reference_cards
      @additional_data_cards = additional_data_cards
      @deduper_cards         = deduper_cards
      @system_settings_cards = system_settings_cards
      @deprecated_data_cards = deprecated_data_cards
      @pending_change_requests_count = ProfileChangeRequest.pending.count
    end

    def badge_counts
      authorize! :home, to: :index?

      @data_health_count = safe_count { DataHealth.checks.sum(&:count) }
      @author_credit_count = safe_count { DataHealth::Worklists.new.author_credit.sum(&:count) }
      @unsynced_features_count = safe_count { FeatureCatalog.new.missing_count } if allowed_to?(:create?, Feature)
      render :badge_counts
    end

    private

    # A badge is a nicety, so a failing count leaves its badge empty and the button usable.
    def safe_count
      yield
    rescue StandardError => e
      Rails.error.report(e)
      nil
    end
  end
end
