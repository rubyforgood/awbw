class NotificationPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    admin?
  end

  def show?
    admin? || owner?
  end

  def resend?
    admin?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    if authenticated?
      relation.where(recipient_email: user.email)
    else
      relation.none
    end
  end

  private

  def owner?
    user.present? && record.recipient_email == user.email
  end
end
