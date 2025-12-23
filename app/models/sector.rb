class Sector < ApplicationRecord
  attr_accessor :_create
  include NameFilterable
  SECTOR_TYPES = ['Veterans & Military', 'Sexual Assault', 'Substance Abuse', 'LGBTQIA',
                  'Child Abuse', 'Education/Schools', 'Domestic Violence', 'Other' ]

  has_many :sectorable_items, dependent: :destroy
  has_many :workshops, through: :sectorable_items,
           source: :sectorable, source_type: 'Workshop'
  # has_many through
  has_many :quotes, through: :workshops

  # Validations
  validates_presence_of :name, uniqueness: true

  # Scopes
  scope :published, ->(published=nil) {
    ["true", "false"].include?(published) ? where(published: published) : where(published: true) }
  scope :published_search, ->(published_search) { published_search.present? ? published(published_search) : all }
  scope :sector_name, ->(sector_name) {
    sector_name.present? ? where("sectors.name LIKE ?", "%#{sector_name}%") : all }
  scope :has_taggings, -> { joins(:sectorable_items).distinct }

end
