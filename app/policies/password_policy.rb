# app/policies/password_policy.rb
class PasswordPolicy < ApplicationPolicy
  def update?
    true # reset via token
  end

  def create?
    true # request reset email
  end
end
