# frozen_string_literal: true

class ReportPolicy < ApplicationPolicy
  # All custom report actions require authentication (handled by pre_check)
  alias_rule :monthly_select_type?, :monthly?, :share_story?, to: :index?
  alias_rule :edit_story?, to: :edit?
  alias_rule :update_story?, to: :update?
  alias_rule :create_story?, to: :create?
end
