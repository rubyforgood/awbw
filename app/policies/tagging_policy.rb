# frozen_string_literal: true

class TaggingPolicy < ApplicationPolicy
  def index?
    authenticated?
  end

  def matrix?
    authenticated?
  end
end
