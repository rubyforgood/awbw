# frozen_string_literal: true

class TagPolicy < ApplicationPolicy
  def index?
    authenticated?
  end

  def sectors?
    authenticated?
  end

  def categories?
    authenticated?
  end
end
