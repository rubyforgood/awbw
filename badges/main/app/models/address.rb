class Address < ApplicationRecord
  belongs_to :organization

  validates :street, presence: true
  validates :city, presence: true
  validates :state, presence: true
  validates :zip, presence: true
end
