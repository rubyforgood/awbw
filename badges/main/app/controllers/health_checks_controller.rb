# Probed by the host's liveness check, so it skips sign-in, tracking, and authorization.
class HealthChecksController < ActionController::Base
  def jobs
    if JobRunnerHealth.alive?
      render plain: "Job runner OK"
    else
      render plain: "Job runner has not checked in", status: :service_unavailable
    end
  end
end
