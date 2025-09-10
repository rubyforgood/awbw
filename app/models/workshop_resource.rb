# frozen_string_literal: true

class WorkshopResource < ApplicationRecord
  belongs_to :workshop
  belongs_to :resource
end
