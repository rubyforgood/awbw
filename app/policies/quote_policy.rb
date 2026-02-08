class QuotePolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    admin?
  end

  def show?
    admin? || owner?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    if authenticated?
      relation.published
    else
      relation.none
    end
  end

  private

  def owner?
    record.recipient_email == user.email
  end
end
