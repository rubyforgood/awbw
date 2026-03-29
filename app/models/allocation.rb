class Allocation < ApplicationRecord
  belongs_to :source, polymorphic: true
  belongs_to :allocatable, polymorphic: true
  validates :amount, numericality: true
end
