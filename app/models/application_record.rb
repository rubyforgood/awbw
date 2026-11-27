class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  include AhoyTrackable
  include UserStampable

  # Records a search box's text names outright: the exact portal id, or (on
  # FileMaker-coded models) one whole FileMaker code.
  def self.matching_identifier(query)
    query = query.to_s.strip
    matches = []
    matches << where(id: query) if query.match?(/\A\d+\z/)
    matches << with_filemaker_code(query) if query.present? && respond_to?(:with_filemaker_code)
    matches.reduce(:or) || none
  end

  # A search box's text search, widened to the record its text names by identifier.
  def self.matching_text_or_identifier(text_scope, query)
    where(id: public_send(text_scope, query).select(:id)).or(where(id: matching_identifier(query).select(:id)))
  end

  def bookmarks_count
    if self.respond_to?(:bookmarks)
      self.bookmarks.length
    else
      0
    end
  end
end
