module Admin
  class HomeController < ApplicationController
    include AdminCardsHelper

    def index
      authorize! :home, to: :index?

      @system_cards       = system_cards
      @user_content_cards = user_content_cards
      @reference_cards    = reference_cards
    end
  end
end
