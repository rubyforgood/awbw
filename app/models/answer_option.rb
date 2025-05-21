class AnswerOption < ApplicationRecord
  default_scope { order(order: :asc) }
end
