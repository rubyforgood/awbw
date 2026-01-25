# frozen_string_literal: true

class ImageMigrationAuditPolicy < ApplicationPolicy
  def index?
    admin?
  end
end
