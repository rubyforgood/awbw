# A word some other system used for a tag the portal now carries its own name for. The
# FileMaker archive, the older registration and scholarship forms, Story Share and the
# portal's own earlier sector list each had their own wording; ADR-0007 records what each
# term resolves to, and these rows are that mapping as data — so an admin can add a term
# as it turns up instead of waiting for a deploy, and the record of what a tag used to be
# called outlives the import that needed it.
#
# A term can name two tags ("C & T" is both Children and Teens), so it is read as a list.
# It can also be recorded as naming nothing on purpose — a FileMaker "setting" like
# "Virtually" says where someone works, not who they serve — which is what keeps a decided
# non-translation out of the queue of terms still needing a decision.
class TagAlias < ApplicationRecord
  SOURCES = %w[filemaker forms story_share portal].freeze

  belongs_to :aliasable, polymorphic: true, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  normalizes :name, with: ->(value) { value.to_s.squish }

  validates :name, presence: true, length: { maximum: 255 },
            uniqueness: { scope: %i[aliasable_type aliasable_id], case_sensitive: false }
  validates :source, inclusion: { in: SOURCES }
  validate :names_a_tag_or_is_ignored

  scope :ignored, -> { where(ignored: true) }
  scope :resolving, -> { where(ignored: false) }

  scope :for_sectors, -> { where(aliasable_type: "Sector") }
  scope :for_categories, -> { where(aliasable_type: "Category") }

  private

  def names_a_tag_or_is_ignored
    return if aliasable.present? ^ ignored?

    errors.add(:base, "A term either names a tag or is ignored, not both and not neither")
  end
end
