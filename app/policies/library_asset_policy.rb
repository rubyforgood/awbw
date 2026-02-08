class LibraryAssetPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy

  def show?    = admin? || owner?
  def create?  = authenticated? # anyone logged in can create an asset
  def edit?    = admin? || owner?
  def update?  = authenticated? # anyone logged in can create an asset
  def destroy? = admin? || owner?
end
