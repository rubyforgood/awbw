class Organization < ApplicationRecord
  has_many :addresses, dependent: :destroy
  has_many :facilitator_organizations, dependent: :restrict_with_exception
  has_many :facilitators, through: :facilitator_organizations
  has_many :organization_workshops, dependent: :restrict_with_exception
  has_many :workshops, through: :organization_workshops

  validates :name, presence: true
  validates :agency_type, presence: true
  validates :phone, presence: true
end
