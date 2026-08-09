class EventRegistrationPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy

  def index?   = admin?
  def create?  = admin? || owner?
  def update?  = admin? || owner?
  def destroy? = record.persisted? && (admin? || owner?)
  def show? = admin?
  def show_public? = true
  def confirm? = admin?
  def process_confirm? = admin?
  def link_organization? = admin?
  def select_organization? = admin?
  def create_organization? = admin?
  def unlink_organization? = admin?
  # Editing the onboarding matrix is an admin management action; event owners
  # (the event's creator) manage their own events' onboarding too.
  def update_onboarding? = admin? || event_owner?
  # Marking a certificate issued from the registrants roster is an event-management
  # action, so mirror the roster's audience (admins and the event's owner).
  def toggle_certificate_issued? = admin? || event_owner?


  relation_scope do |relation|
    return relation if admin?
    return relation.none unless user
    relation.where(registrant_id: user.person_id)
  end

  private

  def owner?
    return false unless user
    record.registrant_id == user.person_id
  end

  def event_owner?
    return false unless user
    record.event&.created_by_id == user.id
  end
end
