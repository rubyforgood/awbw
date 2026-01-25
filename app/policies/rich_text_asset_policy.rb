# frozen_string_literal: true

class RichTextAssetPolicy < ApplicationPolicy
  def index?
    authenticated?
  end

  def show?
    authenticated?
  end

  def create?
    authenticated?
  end

  def edit?
    authenticated?
  end

  def update?
    authenticated?
  end

  def destroy?
    authenticated?
  end
end
