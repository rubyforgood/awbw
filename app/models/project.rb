class Project < ApplicationRecord
  # Associations
  belongs_to :location, optional: true
  belongs_to :project_status
  belongs_to :windows_type, optional: true
  has_many :project_users
  has_many :users, through: :project_users
  has_many :reports, through: :users
  has_many :workshop_logs, through: :users
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  has_many :sectors, through: :sectorable_items

  scope :active, -> { where(inactive: false) }

  # Logo
  ACCEPTED_CONTENT_TYPES = ["image/jpeg", "image/png" ].freeze
  has_one_attached :logo
  validates :logo, content_type: ACCEPTED_CONTENT_TYPES

  validates :name, presence: true
  validates :project_status_id, presence: true

  # Methods
  def led_by?(user)
    return false unless leader
    leader.user == user
  end

  def log_title
    "#{name} #{windows_type.log_label if windows_type}"
  end

  private

  def leader
    project_users.find_by(position: 2)
  end
end
