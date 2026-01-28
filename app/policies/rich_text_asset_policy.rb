# frozen_string_literal: true

class RichTextAssetPolicy < ApplicationPolicy
  # Any authenticated user can destroy rich text assets
  def destroy?
    true
  end
end
