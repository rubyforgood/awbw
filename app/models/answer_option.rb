# frozen_string_literal: true

class AnswerOption < ApplicationRecord
  default_scope { order(order: :asc) }
end
