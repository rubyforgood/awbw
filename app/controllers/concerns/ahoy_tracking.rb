module AhoyTracking
  extend ActiveSupport::Concern

  def track(action, resource)
    Analytics::AhoyTracker.track(self, action, resource)
  end

  # Sugar for controllers (readability)
  def track_view(resource)    = track(:view, resource)
  def track_print(resource)   = track(:print, resource)
  def track_download(resource)= track(:download, resource)

  def track_create(resource)  = track(:create, resource)
  def track_update(resource)  = track(:update, resource)
  def track_destroy(resource) = track(:destroy, resource)
end
