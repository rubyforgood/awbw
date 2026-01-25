# frozen_string_literal: true

class ContactUsPolicy < ApplicationPolicy
  def index?
    authenticated?
  end

  def create?
    authenticated?
  end
end
