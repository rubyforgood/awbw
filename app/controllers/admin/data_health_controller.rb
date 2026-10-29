module Admin
  # Data health: consistency checks that span the whole database, each with a count
  # and — where a correct fix exists — a button to apply it. See DataHealth::Check.
  class DataHealthController < ApplicationController
    include AhoyTracking

    def index
      authorize! :data_health, to: :index?
      track_view("admin.data_health")

      @groups = DataHealth.grouped_checks
      @background_jobs = BackgroundJobsStatus.new if BackgroundJobsStatus.available?
      @open_check = params[:open]
    end

    def worklists
      authorize! :data_health, to: :index?

      @worklists = DataHealth::Worklists.new
      render :data_health_worklists
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

    def restart_app
      authorize! :data_health
      return redirect_to admin_data_health_path, alert: "Restarting isn't available here." unless AppRestart.available?

      track_event("restart.app")
      AppRestart.call
      redirect_to admin_data_health_path, notice: "Restarting the app. The site will be down for a minute or two."
    end

    def retry_interrupted_jobs
      authorize! :data_health
      return redirect_to admin_data_health_path, alert: "Background jobs aren't tracked here." unless BackgroundJobsStatus.available?

      retried = BackgroundJobsStatus.new.retry_interrupted!
      redirect_to admin_data_health_path(anchor: "background-jobs"), notice: "Retried #{retried} #{"job".pluralize(retried)}."
    end
  end
end
