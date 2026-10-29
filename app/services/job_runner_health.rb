# Liveness of the Solid Queue runner that puma hosts (SOLID_QUEUE_IN_PUMA): its
# async threads can die while the web server keeps serving, and nothing restarts them.
class JobRunnerHealth
  def self.alive?
    return true if ENV["SOLID_QUEUE_IN_PUMA"].blank?

    last_heartbeat_at = last_worker_heartbeat_at
    last_heartbeat_at.present? && last_heartbeat_at > SolidQueue.process_alive_threshold.ago
  end

  def self.last_worker_heartbeat_at
    SolidQueue::Process.where(kind: "Worker", hostname: Socket.gethostname).maximum(:last_heartbeat_at)
  end
end
