# frozen_string_literal: true

class Banner < ApplicationRecord
  # Validations
  validates :content, presence: true
end
