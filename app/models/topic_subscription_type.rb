class TopicSubscriptionType < ApplicationRecord
  # Canonical types seeded for all environments. Admins can add/edit/archive more.
  CANONICAL = {
    "facilitator_trainings" => "Facilitator trainings",
    "news" => "News",
    "resources" => "Resources"
  }.freeze
  # The type the registration form's `interested_in_more` answer maps to when we
  # backfill/auto-capture subscriptions (see follow-up).
  INTERESTED_IN_MORE_KEY = "facilitator_trainings"

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  has_many :topic_subscriptions, dependent: :restrict_with_error

  before_validation :set_key, on: :create

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :key, presence: true, uniqueness: true

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :ordered, -> { order(:name) }

  def self.interested_in_more
    find_by(key: INTERESTED_IN_MORE_KEY)
  end

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def unarchive!
    update!(archived_at: nil)
  end

  def to_s
    name
  end

  private

  # Derive a stable slug from the name once, at creation. The display name stays
  # editable; the key doesn't.
  def set_key
    self.key ||= name.to_s.parameterize(separator: "_").presence
  end
end
