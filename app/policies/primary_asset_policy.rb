class PrimaryAssetPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy
  #
  # TODO check the policy of the record that owns this asset
  def show?    = admin?
  def create?  = authenticated?
  def edit?    = admin?
  def update?  = authenticated?
  def destroy? = record.persisted? && admin?
end
