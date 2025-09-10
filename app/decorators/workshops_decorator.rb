# frozen_string_literal: true

class WorkshopsDecorator < Draper::CollectionDecorator
  delegate :current_page, :per_page, :offset, :total_entries, :total_pages
end
