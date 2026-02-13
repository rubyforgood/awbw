class UserPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index? = admin?
  def show? = admin? # later: show? || self?
  def new? = admin?
  def create? = admin?
  def edit? = admin?
  def update? = admin?
  def destroy? = record.persisted? && admin?
  def toggle_lock_status? = admin?
  def confirm_email? = admin?
  def send_welcome_instructions? = admin?
  def change_password? = authenticated?
  def update_password? = authenticated?

  relation_scope do |relation|
    next relation if admin?
    relation.where(id: user.id)
  end

  private

  def self?
    user == record
  end
end
