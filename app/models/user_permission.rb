# frozen_string_literal: true

class UserPermission < ApplicationRecord
  belongs_to :user
  belongs_to :permission
end
