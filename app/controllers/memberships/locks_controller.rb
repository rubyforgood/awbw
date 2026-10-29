module Memberships
  class LocksController < ApplicationController
    before_action :set_membership

    def destroy
      authorize! @membership

      if @membership.locked?
        @membership.update!(locked_at: nil)
        redirect_to membership_path(@membership),
          notice: "Membership unlocked. Turn renewal on and issue the next invoice if needed.",
          status: :see_other
      else
        redirect_to membership_path(@membership),
          alert: "This membership is not locked.", status: :see_other
      end
    end

    private

    def set_membership
      @membership = Membership.find(params[:membership_id])
    end
  end
end
