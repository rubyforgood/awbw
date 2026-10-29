module Memberships
  class AutopayController < ApplicationController
    before_action :set_membership

    def update
      enabled = ActiveModel::Type::Boolean.new.cast(params[:autopay_on])
      authorize! @membership, to: (enabled ? :enable_autopay? : :disable_autopay?)

      if enabled && !card_on_file?
        return redirect_to autopay_destination,
          alert: "Add a card before turning on automatic payments.", status: :see_other
      end

      @membership.update!(autopay_on: enabled)
      redirect_to autopay_destination,
        notice: enabled ? "Automatic payments are on." : "Automatic payments are off.",
        status: :see_other
    end

    private

    def set_membership
      @membership = Membership.find(params[:membership_id])
    end

    def card_on_file?
      @membership.person.stripe_customer&.payment_methods&.exists? || false
    end

    def autopay_destination
      allowed_to?(:show?, @membership) ? membership_path(@membership) : person_path(@membership.person)
    end
  end
end
