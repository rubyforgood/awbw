module Memberships
  class BulkActionsController < ApplicationController
    before_action :set_action
    before_action :set_directory

    def new
      authorize! :membership
      prepare_confirm
    end

    def create
      authorize! :membership

      ids = Array(params[@action.param_name]).reject(&:blank?).map(&:to_i)
      @selected_ids = ids
      @cost_cents = fee_action? ? MoneyParser.cents(params[:cost_dollars]) : nil

      return render_confirm_error("Select at least one row.") if ids.empty?

      if fee_action? && MoneyParser.invalid?(@cost_cents)
        return render_confirm_error("Enter the fee as a number, e.g. 20 or 19.50.")
      end

      result = @action.perform(@directory, ids: ids, cost_cents: @cost_cents)
      redirect_to memberships_path(@directory.filter_params),
        notice: @action.notice(result), status: :see_other
    end

    private

    def set_action
      @action = Membership::BulkAction.for(params[:action_key])
      redirect_to memberships_path, alert: "Unknown bulk action." unless @action
    end

    def set_directory
      @directory = MembershipDirectory.new(params)
    end

    def fee_action?
      @action.key == "set_fee"
    end

    def prepare_confirm
      @rows = @action.preview_rows(@directory)
      @selected_count = @selected_ids ? @selected_ids.size : @rows.count(&:actionable?)
    end

    def render_confirm_error(message)
      @error = message
      prepare_confirm
      render :new, status: :unprocessable_content
    end
  end
end
