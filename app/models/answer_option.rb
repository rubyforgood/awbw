class AnswerOption < ApplicationRecord
  default_scope { order(position: :asc) }
end
