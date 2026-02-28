class EventRegistration < ApplicationRecord
  belongs_to :registrant, class_name: "Person"
  belongs_to :event
  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :destroy
  has_many :payments, as: :payable

  before_destroy :create_refund_payments

  accepts_nested_attributes_for :comments, reject_if: proc { |attrs| attrs["body"].blank? }

  ACTIVE_STATUSES = %w[ registered attended incomplete_attendance ].freeze
  INACTIVE_STATUSES = %w[ cancelled no_show ].freeze
  ATTENDANCE_STATUSES = (ACTIVE_STATUSES + INACTIVE_STATUSES).freeze

  # Validations
  validates :registrant_id, uniqueness: { scope: :event_id }
  validates :event_id, presence: true
  validates :status, inclusion: { in: ATTENDANCE_STATUSES }, allow_nil: false

  # Scopes
  scope :registrant_name, ->(registrant_name) { joins(:registrant).where(
    "LOWER(REPLACE(CONCAT(people.first_name, people.last_name), ' ', '')) LIKE :name
    OR LOWER(REPLACE(CONCAT(people.last_name, people.first_name), ' ', '')) LIKE :name
    OR LOWER(REPLACE(people.first_name, ' ', '')) LIKE :name
    OR LOWER(REPLACE(people.last_name, ' ', '')) LIKE :name", name: "%#{registrant_name}%") }
  scope :event_title, ->(event_title) { joins(:event).where("LOWER(events.title LIKE ?)", "%#{event_title}%") }
  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :attendance_status, ->(status) { where(status: status) }
  scope :keyword, ->(term) {
    return none if term.blank?

    sanitized = "%#{sanitize_sql_like(term.downcase.strip)}%"
    left_joins(registrant: [ :user, :contact_methods, :addresses, { affiliations: [ :organization ] } ])
      .left_joins(registrant: { affiliations: { organization: :addresses } })
      .where(
        "LOWER(people.first_name) LIKE :term
        OR LOWER(people.last_name) LIKE :term
        OR LOWER(CONCAT(people.first_name, ' ', people.last_name)) LIKE :term
        OR LOWER(users.email) LIKE :term
        OR LOWER(people.email) LIKE :term
        OR LOWER(contact_methods.value) LIKE :term
        OR LOWER(addresses.city) LIKE :term
        OR LOWER(addresses.phone) LIKE :term
        OR LOWER(organizations.name) LIKE :term",
        term: sanitized
      )
      .distinct
  }

  def self.search_by_params(params)
    registrations = is_a?(ActiveRecord::Relation) ? self : all
    if params[:registrant_id].present?
      registrations = registrations.where(registrant_id: params[:registrant_id])
    elsif params[:registrant_name].present?
      registrations = registrations.registrant_name(params[:registrant_name].downcase.strip)
    end
    if params[:event_id].present?
      registrations = registrations.where(event_id: params[:event_id])
    elsif params[:event_name].present?
      registrations = registrations.event_title(params[:event_name].downcase.strip)
    end
    registrations
  end

  def name
    "(#{ registrant&.full_name }) #{ event.start_date.strftime("%Y-%m-%d @ %I:%M %p") }: #{ event.title }"
  end

  def active?
    status.in?(ACTIVE_STATUSES)
  end

  def checked_in?
    # checked_in_at.present?
  end

  def paid?
    paid_in_full?
  end

  # True if event is free or total successful payments >= event.cost_cents
  def paid_in_full?
    return true if event.cost_cents.to_i <= 0
    payments.successful.sum(:amount_cents) >= event.cost_cents.to_i
  end

  def scholarship?
    payments.scholarships.exists?
  end

  def scholarship_tasks_met?
    return true unless scholarship?
    scholarship_tasks_completed?
  end

  def joinable?
    active? && paid? && scholarship_tasks_met?
  end

  def attendance_status_label
    return "—" if status.blank?
    case status
    when "registered" then "Registered"
    when "attended" then "Attended"
    when "incomplete_attendance" then "Incomplete attendance"
    when "cancelled" then "Cancelled"
    when "no_show" then "No show"
    else status.humanize
    end
  end

  private

  def create_refund_payments
    paid_cents = payments.successful.sum(:amount_cents)
    return if paid_cents <= 0

    payments.create!(
      amount_cents: -paid_cents,
      payer: registrant,
      event: event,
      payment_type: "refund",
      status: "refunded",
      currency: "usd"
    )
  end
end
