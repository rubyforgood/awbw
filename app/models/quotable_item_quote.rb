class QuotableItemQuote < ApplicationRecord
  belongs_to :quote
  belongs_to :quotable, polymorphic: true

  accepts_nested_attributes_for :quote, allow_destroy: true
end
