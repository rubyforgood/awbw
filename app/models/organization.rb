class Organization < ApplicationRecord
  has_many :addresses, dependent: :destroy
  has_many :facilitator_organizations, dependent: :restrict_with_exception
  has_many :facilitators, through: :facilitator_organizations

  validates :name, presence: true
  validates :agency_type, presence: true
  validates :phone, presence: true
end
