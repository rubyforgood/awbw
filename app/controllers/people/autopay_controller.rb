module People
  class AutopayController < ApplicationController
    before_action :set_person

    def update
      enabled = ActiveModel::Type::Boolean.new.cast(params[:autopay_on])
      authorize! @person, to: (enabled ? :enable_autopay? : :disable_autopay?)

      unless Membership.enabled?
        return redirect_to person_path(@person), alert: "Memberships are not available right now.",
          status: :see_other
      end

      if enabled && !card_on_file?
        return redirect_to person_path(@person),
          alert: "Add a card before turning on automatic payments.", status: :see_other
      end

      @person.update!(autopay_on: enabled)
      redirect_to person_path(@person),
        notice: enabled ? "Automatic payments are on." : "Automatic payments are off.",
        status: :see_other
    end

    private

    def set_person
      @person = Person.find(params[:person_id])
    end

    def card_on_file?
      @person.payment_processor&.payment_methods&.exists? || false
    end
  end
end
