module Admin
  # A deliberately unlinked page, reached only by typing its URL, with one button that
  # restarts the app. See AppRestart.
  class RestartsController < ApplicationController
    include AhoyTracking

    def show
      authorize! :restart
    end

    def create
      authorize! :restart
      return redirect_to admin_restart_path, alert: "Restarting isn't available here." unless AppRestart.available?

      track_event("restart.app")
      AppRestart.call
      redirect_to admin_restart_path, notice: "Restarting the app. The site will be down for a minute or two."
    end
  end
end
