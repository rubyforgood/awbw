# frozen_string_literal: true

class LibraryAssetPolicy < ApplicationPolicy
  # Any authenticated user can destroy library assets
  def destroy?
    true
  end
end
