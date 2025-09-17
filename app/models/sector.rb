class Sector < ApplicationRecord
  # Associations
  has_many :sectorable_items, dependent: :destroy

  has_many :workshops, through: :sectorable_items,
           source: :sectorable, source_type: 'Workshop'

  has_many :quotes, through: :workshops

  # Validations
  validates_presence_of :name, uniqueness: true

  # ATTR Accessor
  attr_accessor :_create

  default_scope { order('name') }

  # Scopes
  scope :published, -> { where(published: true).
                         order(Arel.sql("CASE WHEN name = 'Other' THEN 1 ELSE 0 END, LOWER(name) ASC")) }

  # Methods
  def self.create_defaults
    Sector.defaults.each do | name |
      Sector.find_or_create_by(name: name, published: true)
    end
  end

  private

  def self.defaults
    ['Veterans & Military', 'Sexual Assault', 'Addiction Recovery',
     'LGBTQIA', 'Child Abuse', 'Education/Schools', 'Other' ]
  end
end
