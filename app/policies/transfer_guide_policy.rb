class TransferGuidePolicy < ApplicationPolicy
  # Admin-facing reference page (linked from Features & tips).
  def show? = admin?
end
