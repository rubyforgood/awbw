class Sector < ApplicationRecord
  attr_accessor :_create

  SECTOR_TYPES = ['Veterans & Military', 'Sexual Assault', 'Addiction Recovery',
                  'LGBTQIA', 'Child Abuse', 'Education/Schools', 'Other' ]

  has_many :sectorable_items, dependent: :destroy
  has_many :workshops, through: :sectorable_items,
           source: :sectorable, source_type: 'Workshop'
  # has_many through
  has_many :quotes, through: :workshops

  # Validations
  validates_presence_of :name, uniqueness: true

  # Scopes
  scope :published, -> { where(published: true).
                         order(Arel.sql("CASE WHEN name = 'Other' THEN 1 ELSE 0 END, LOWER(name) ASC")) }


  def self.create_defaults
    SECTOR_TYPES.each do | name |
      Sector.find_or_create_by(name: name, published: true)
    end
  end
end
