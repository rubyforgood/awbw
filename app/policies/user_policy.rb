class UserPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index? = admin?
  def show? = admin?
  def new? = admin?
  def create? = admin?
  def edit? = admin?
  def update? = admin?
  def destroy? = admin?
  def toggle_lock_status? = admin?
  def confirm_email? = admin?
  def change_password?
    authenticated?
  end
  def update_password?
    authenticated?
  end
end
