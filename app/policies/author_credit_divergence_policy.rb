class AuthorCreditDivergencePolicy < ApplicationPolicy
  def index?
    admin?
  end

  def update_person?
    admin?
  end

  def update_item?
    admin?
  end

  def assign_author?
    admin?
  end
end
