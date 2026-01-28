# frozen_string_literal: true

class WorkshopVariationPolicy < ApplicationPolicy
  # index = admin only

  def index?
    admin?
  end
end
