module Admin
  class HomeController < Admin::BaseController
    include AdminCardsHelper

    def index
      return redirect_to root_path, alert: "You do not have permission." unless current_user.super_user?

      @system_cards       = system_cards
      @user_content_cards = user_content_cards
      @reference_cards    = reference_cards
    end
  end
end
