class AssetPolicy < ApplicationPolicy
  # The admin image index and its inline title editing are admin-only,
  # regardless of the asset's STI subtype.
  def index?  = admin?
  def update? = admin?
end
