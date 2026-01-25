# frozen_string_literal: true

class WorkshopLogCreationWizardPolicy < ApplicationPolicy
  def show?
    authenticated?
  end

  def update?
    authenticated?
  end
end
