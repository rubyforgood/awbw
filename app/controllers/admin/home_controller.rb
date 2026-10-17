module Admin
  class HomeController < ApplicationController
    include AdminCardsHelper

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

    def data_health_count
      authorize! :home, to: :index?

      render_count_badge(:data_health_count) { DataHealth.checks.sum(&:count) }
    end

    def author_credit_count
      authorize! :home, to: :index?

      render_count_badge(:author_credit_count) { DataHealth::Worklists.new.author_credit.sum(&:count) }
    end

    private

    # A badge is a nicety, so a failing count renders an empty frame and leaves the button usable.
    def render_count_badge(frame_id)
      count = begin
        yield
      rescue StandardError => e
        Rails.error.report(e)
        nil
      end
      render partial: "count_badge_frame", locals: { frame_id: frame_id, count: count }
    end
  end
end
