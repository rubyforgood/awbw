class AssetPolicy < ApplicationPolicy
  # The admin image index, its inline title editing, and creating a new library
  # asset are admin-only, regardless of the asset's STI subtype.
  def index?  = admin?
  def new?    = admin?
  def create? = admin?
  def update? = admin?
end
