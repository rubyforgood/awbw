class Organization < ApplicationRecord
  has_many :addresses, dependent: :destroy

  validates :name, presence: true
  validates :agency_type, presence: true
  validates :phone, presence: true
end
