module Admin
  class HomeController < ApplicationController
    include AdminCardsHelper

    REVIEW_BADGE = "Review".freeze
    DATA_HEALTH_BADGE_TITLE = "Data checks only. Possible duplicates and author credit are listed separately on the Data health page.".freeze

    def index
      authorize! :home

      @system_cards          = system_cards
      @user_content_cards    = user_content_cards
      @reference_cards       = reference_cards
      @additional_data_cards = additional_data_cards
      @deduper_cards         = deduper_cards
      @system_settings_cards = system_settings_cards
      @deprecated_data_cards = deprecated_data_cards
    end

    def action_buttons
      authorize! :home, to: :index?

      @pending_change_requests_count = safely { ProfileChangeRequest.pending.count }
      @data_health_flagged = safely { DataHealth.checks.any?(&:flagged?) }
      @author_credit_flagged = safely { AuthorCreditDivergenceQuery.new.any? }
      @features_unsynced = safely { FeatureCatalog.new.recent_missing? } if allowed_to?(:create?, Feature)
    end

    private

    # A badge is a nicety, so a failing check leaves its badge empty and the buttons usable.
    def safely
      yield
    rescue StandardError => e
      Rails.error.report(e)
      nil
    end
  end
end
