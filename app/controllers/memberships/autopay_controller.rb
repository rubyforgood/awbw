module Memberships
  class AutopayController < ApplicationController
    before_action :set_membership

    def update
      authorize! @membership, to: :disable_autopay?
      @membership.update!(autopay_on: false)
      redirect_to autopay_destination, notice: "Automatic payments are off.", status: :see_other
    end

    private

    def set_membership
      @membership = Membership.find(params[:membership_id])
    end

    def autopay_destination
      allowed_to?(:show?, @membership) ? membership_path(@membership) : person_path(@membership.person)
    end
  end
end
