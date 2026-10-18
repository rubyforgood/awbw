class AnswerOption < ApplicationRecord
  NAME_MAX_LENGTH = 1000

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  validates :name, length: { maximum: NAME_MAX_LENGTH }

  default_scope { order(position: :asc) }
end
