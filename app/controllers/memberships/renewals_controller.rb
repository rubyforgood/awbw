module Memberships
  class RenewalsController < ApplicationController
    before_action :set_membership

    def update
      authorize! @membership

      renewal_on = ActiveModel::Type::Boolean.new.cast(params[:renewal_on])

      if renewal_on && (reason = @membership.renewal_blocked_reason)
        return redirect_to membership_path(@membership),
          alert: reason, status: :see_other
      end

      @membership.update!(renewal_off_at: renewal_on ? nil : Time.current)

      redirect_to membership_path(@membership),
        notice: renewal_on ? "Renewal turned on." : "Renewal turned off.",
        status: :see_other
    end

    private

    def set_membership
      @membership = Membership.find(params[:membership_id])
    end
  end
end
