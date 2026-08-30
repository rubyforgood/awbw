class AnswerOption < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  default_scope { order(position: :asc) }
end
