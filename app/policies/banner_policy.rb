# frozen_string_literal: true

class BannerPolicy < ApplicationPolicy
  alias_rule :edit?, to: :update?
end
