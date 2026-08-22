module Admin
  # Data health: consistency checks that span the whole database, each with a count
  # and — where a correct fix exists — a button to apply it. See DataHealth::Check.
  class DataHealthController < ApplicationController
    include AhoyTracking

    def index
      authorize! :data_health, to: :index?
      track_view("admin.data_health")

      @checks = DataHealth.checks
    end

    def repair
      authorize! :data_health, to: :repair?

      check = DataHealth.find(params[:check])
      return redirect_to admin_data_health_path, alert: "Unknown check." unless check&.repairable?

      repaired = check.repair!
      redirect_to admin_data_health_path, notice: check.repaired_message(repaired)
    end
  end
end
