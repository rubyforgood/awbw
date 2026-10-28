module Admin
  # Data health: consistency checks that span the whole database, each with a count
  # and — where a correct fix exists — a button to apply it. See DataHealth::Check.
  class DataHealthController < ApplicationController
    include AhoyTracking

    def index
      authorize! :data_health, to: :index?
      track_view("admin.data_health")

      @groups = DataHealth.grouped_checks
      @open_check = params[:open]
    end

    def worklists
      authorize! :data_health, to: :index?

      @worklists = DataHealth::Worklists.new
      render :data_health_worklists
    end

    def filemaker_not_imported
      authorize! :data_health, to: :index?

      @kind = DataHealth::FilemakerNotImported.kind(params[:kind])
      return unless turbo_frame_request?

      @not_imported = DataHealth::FilemakerNotImported.new
      @records = @not_imported.page(@kind, params[:page].to_i.clamp(1, Float::INFINITY))
      render :filemaker_not_imported_results
    end

    def rows
      authorize! :data_health, to: :index?

      @check = DataHealth.find(params[:check])
      return head :not_found unless @check

      @page = params[:page].to_i.clamp(1, Float::INFINITY)
      render :data_health_rows
    end

    def repair
      authorize! :data_health, to: :repair?

      check = DataHealth.find(params[:check])
      return redirect_to admin_data_health_path, alert: "Unknown check." unless check&.repairable?

      repaired = check.repair!
      redirect_to admin_data_health_path(open: check.key, anchor: "check-#{check.key}"),
                  notice: check.repaired_message(repaired)
    end
  end
end
