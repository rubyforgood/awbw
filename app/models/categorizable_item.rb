class CategorizableItem < ApplicationRecord
  # Associations
  belongs_to :categorizable, polymorphic: true
  belongs_to :category

  # Attr Accessor
  attr_accessor :_create
end
