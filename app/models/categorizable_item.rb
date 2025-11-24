class CategorizableItem < ApplicationRecord
  attr_accessor :_create

  belongs_to :categorizable, polymorphic: true
  belongs_to :category
end
