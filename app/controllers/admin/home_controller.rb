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
      @deprecated_data_cards = deprecated_data_cards
      @pending_change_requests_count = ProfileChangeRequest.pending.count
    end
  end
end
