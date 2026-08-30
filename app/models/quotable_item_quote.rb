class QuotableItemQuote < ApplicationRecord
  belongs_to :quote
  belongs_to :quotable, polymorphic: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  # Nested attributes
  accepts_nested_attributes_for :quote, allow_destroy: true
end
