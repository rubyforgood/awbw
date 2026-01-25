# frozen_string_literal: true

class ReportPolicy < ApplicationPolicy
  def show?
    authenticated?
  end

  def monthly_select_type?
    authenticated?
  end

  def monthly?
    authenticated?
  end

  def share_story?
    authenticated?
  end

  def edit?
    authenticated?
  end

  def edit_story?
    authenticated?
  end

  def update?
    authenticated?
  end

  def update_story?
    authenticated?
  end

  def create?
    authenticated?
  end

  def create_story?
    authenticated?
  end
end
