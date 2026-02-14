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

  relation_scope(:colleagues) do |relation|
    next relation.active if admin?

    colleague_person_ids = OrganizationPerson.where(
      organization_id: user.organization_ids
    ).select(:person_id)
    relation.where(person_id: colleague_person_ids).or(relation.where(id: user.id))
  end

  private

  def self?
    user == record
  end
end
