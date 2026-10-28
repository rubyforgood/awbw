module Memberships
  class NextYearsController < ApplicationController
    before_action :set_membership

    def destroy
      authorize! @membership, to: :update?

      result = Membership::RemoveNextYear.call(membership: @membership)
      if result.success?
        redirect_to membership_path(@membership),
          notice: "Next year removed. Renewal is now off.", status: :see_other
      else
        redirect_to membership_path(@membership),
          alert: result.errors.to_sentence, status: :see_other
      end
    end

    private

    def set_membership
      @membership = Membership.find(params[:membership_id])
    end
  end
end
