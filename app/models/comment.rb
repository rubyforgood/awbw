class Comment < ApplicationRecord
  include Timelineable

  belongs_to :commentable, polymorphic: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  # Required for new comments only — existing comments (some legacy ones may have
  # blank bodies) must stay savable, so this is intentionally not a blanket
  # validation. The UI enforces it client-side via the field-required controller.
  validates :body, presence: true, unless: :persisted?

  scope :newest_first, -> { order(created_at: :desc) }
  scope :flagged, -> { where(flagged: true) }

  # Body/topic keyword match.
  scope :matching, ->(term) {
    pattern = "%#{sanitize_sql_like(term.to_s.strip.downcase)}%"
    where("LOWER(comments.body) LIKE :pattern OR LOWER(comments.topic) LIKE :pattern", pattern: pattern)
  }

  # Comments a given staff user created or last edited — the author filter picks
  # a specific user via the remote-select (which searches by person name/email).
  scope :authored_by_user, ->(user_id) {
    where("comments.created_by_id = :id OR comments.updated_by_id = :id", id: user_id)
  }

  # Topic-only match. The counterpart of a communication's subject line, so one
  # box can search both in the combined feed (`query` searches the body too).
  scope :topic_matching, ->(term) {
    pattern = "%#{sanitize_sql_like(term.to_s.strip.downcase)}%"
    where("LOWER(comments.topic) LIKE :pattern", pattern: pattern)
  }

  # A comment's follow-up axis is its flag, which lines up with a communication's
  # responded flag: "needed" is an open item on either side. Nothing on a comment
  # records that a reply was sent, so "responded" matches no comment.
  scope :follow_up_status, ->(status) {
    case status.to_s
    when "needed" then flagged
    when "none" then where(flagged: false)
    when "responded" then none
    else all
    end
  }

  scope :created_on_or_after, ->(value) {
    date = parse_date(value)
    date ? where("comments.created_at >= ?", date.beginning_of_day) : all
  }

  scope :created_on_or_before, ->(value) {
    date = parse_date(value)
    date ? where("comments.created_at <= ?", date.end_of_day) : all
  }

  # Every comment connected to a person (profile, registrations, scholarships, CE
  # registrations, user account) — reuses the aggregator so this and the person
  # page stay in lockstep.
  scope :for_person, ->(person_id) {
    person = Person.find_by(id: person_id)
    next none unless person
    where(id: PersonCommentAggregator.new(person).comments.select(:id))
  }

  # Every comment connected to an event: its registrations, their CE
  # registrations, and the scholarships allocated to those registrations.
  scope :for_event, ->(event_id) {
    registration_ids = EventRegistration.where(event_id: event_id).ids
    next none if registration_ids.empty?
    ce_ids = ContinuingEducationRegistration.where(event_registration_id: registration_ids).ids
    scholarship_ids = Scholarship.joins(:allocation)
      .where(allocations: { allocatable_type: "EventRegistration", allocatable_id: registration_ids }).ids
    where(commentable_type: "EventRegistration", commentable_id: registration_ids)
      .or(where(commentable_type: "ContinuingEducationRegistration", commentable_id: ce_ids))
      .or(where(commentable_type: "Scholarship", commentable_id: scholarship_ids))
  }

  def self.search_by_params(params)
    scope = is_a?(ActiveRecord::Relation) ? self : all
    scope = scope.where(commentable_type: params[:source]) if params[:source].present?
    scope = scope.flagged if params[:flagged] == "1"
    scope = scope.follow_up_status(params[:follow_up]) if params[:follow_up].present?
    scope = scope.matching(params[:query]) if params[:query].present?
    scope = scope.topic_matching(params[:subject]) if params[:subject].present?
    scope = scope.authored_by_user(params[:author_id]) if params[:author_id].present?
    scope = scope.created_on_or_after(params[:from]) if params[:from].present?
    scope = scope.created_on_or_before(params[:to]) if params[:to].present?
    scope = scope.for_person(params[:person_id]) if params[:person_id].present?
    scope = scope.for_event(params[:event_id]) if params[:event_id].present?
    scope
  end

  def self.parse_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def timeline_label
    return "Comment" unless commentable.present?
    "Comment on #{commentable.timeline_label}"
  end

  private

  def timeline_changes
    super.except("commentable_id", "commentable_type")
  end

  def record_timeline_event(action)
    return unless action == "created"

    targets = TimelineServices::Router.targets_for(self)
    return if targets.empty?

    TimelineServices::RecordEvent.call(subject: self, action: action, snapshot: { "changes" => timeline_changes })
  end
end
