class StaffTagging < ApplicationRecord
  include Communicable

  belongs_to :staff_tag
  belongs_to :staff_taggable, polymorphic: true, touch: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy
  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attrs| attrs["body"].blank? }

  validates :staff_tag_id,
            uniqueness: { scope: [ :staff_taggable_type, :staff_taggable_id ], message: "has already been added" }

  # The taggable is always a Person today; guard the polymorphism so a comm logged
  # here is addressed to them.
  def communications_email
    staff_taggable.try(:preferred_email)
  end

  before_create :stamp_created_by
  before_save :stamp_updated_by

  scope :for_staff_tag, ->(ids) {
    tag_ids = Array(ids).reject(&:blank?)
    return all if tag_ids.empty?
    where(staff_tag_id: tag_ids) }

  # Free-text match on the tagged person: their own searchable fields (name,
  # email, phone, address — Person's SearchCop) plus their affiliated
  # organization's name. Taggings are Person-only today, so other taggable types
  # never match. Comment/communication text is unioned in via matching_person_ids.
  scope :matching_text, ->(query) {
    return all if query.blank?
    where(staff_taggable_type: "Person", staff_taggable_id: matching_person_ids(query)) }

  # Seam for the single search field. Each source contributes person ids; add
  # comment/communication matches here so they join the same OR.
  def self.matching_person_ids(query)
    Person.search(query).ids | Person.organization_name(query).ids
  end

  # Matches the tagging's own logged comments and communications (notifications)
  # by their text — the content recorded on the edit page.
  scope :matching_content, ->(query) {
    return all if query.blank?
    like = "%#{sanitize_sql_like(query)}%"
    comment_ids = Comment.where(commentable_type: name)
                         .where("comments.body LIKE :q OR comments.topic LIKE :q", q: like)
                         .select(:commentable_id)
    communication_ids = Notification.where(noticeable_type: name)
                                    .where("notifications.email_subject LIKE :q OR notifications.email_body_text LIKE :q OR notifications.custom_subject LIKE :q OR notifications.custom_message LIKE :q", q: like)
                                    .select(:noticeable_id)
    where(id: comment_ids).or(where(id: communication_ids)) }

  def self.search_by_params(params)
    results = all
    results = results.for_staff_tag(params[:staff_tag_ids]) if params[:staff_tag_ids].present?
    results = results.matching_text(params[:query]) if params[:query].present?
    results = results.matching_content(params[:content]) if params[:content].present?
    results
  end

  private

  def stamp_created_by
    self.created_by ||= Current.user
  end

  def stamp_updated_by
    self.updated_by = Current.user if Current.user
  end
end
