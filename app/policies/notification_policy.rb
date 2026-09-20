class NotificationPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    admin?
  end

  def show?
    admin? || owner?
  end

  def new?
    admin?
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def resend?
    admin? && record.resendable?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    next relation.none unless authenticated?
    # A non-admin only sees transactional emails addressed to their own email —
    # never staff hand logs about them, nor admin bulk sends.
    relation.where(recipient_email: user.email).transactional_emails
  end

  private

  def owner?
    user.present? && record.recipient_email == user.email
  end
end
