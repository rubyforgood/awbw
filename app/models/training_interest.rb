class TrainingInterest < ApplicationRecord
  # Lifecycle: "open" (raised their hand), "converted" (filed a real
  # registration), "closed" (no longer pursuing / training happened without them).
  STATUSES = %w[ open converted closed ].freeze
  STATUS_LABELS = {
    "open" => "Open",
    "converted" => "Converted",
    "closed" => "Closed"
  }.freeze

  belongs_to :person
  # Null means general interest in future trainings; set means a specific event.
  belongs_to :event, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  before_validation :set_expressed_at, on: :create

  validates :status, inclusion: { in: STATUSES }, allow_nil: false
  validate :no_duplicate_open_interest, on: :create

  scope :open, -> { where(status: "open") }
  scope :converted, -> { where(status: "converted") }
  scope :closed, -> { where(status: "closed") }
  scope :general, -> { where(event_id: nil) }
  scope :for_event, ->(event) { where(event: event) }
  scope :newest_first, -> { order(expressed_at: :desc) }

  # Interest not tied to a specific scheduled training.
  def general?
    event_id.nil?
  end

  def status_label
    STATUS_LABELS.fetch(status, status.humanize)
  end

  # Mark as converted once the person files a real registration. Interest seeds a
  # registration, it never becomes one, so the record stays for its history.
  def convert!
    update!(status: "converted")
  end

  private

  def set_expressed_at
    self.expressed_at ||= Time.current
  end

  # One live signal per person per training (general interest = a null event).
  # Doesn't block re-expressing interest after a prior one converted or closed.
  def no_duplicate_open_interest
    return unless status == "open"

    duplicates = TrainingInterest.open.where(person_id: person_id, event_id: event_id)
    duplicates = duplicates.where.not(id: id) if persisted?
    return unless duplicates.exists?

    errors.add(:base, "already has an open interest for this training")
  end
end
