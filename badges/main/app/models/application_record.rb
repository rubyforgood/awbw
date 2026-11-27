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
    matches << with_filemaker_code(query) if respond_to?(:with_filemaker_code) && FilemakerCoded.code_shaped?(query)
    matches.reduce(:or) || none
  end

  # A search box's text search, widened to the record its text names by identifier. The
  # identifier ids come first in their own small query, so the usual text-only search
  # runs unchanged when nothing matches by identifier.
  def self.matching_text_or_identifier(text_scope, query)
    text_matches = public_send(text_scope, query)
    identifier_ids = unscoped.matching_identifier(query).pluck(:id)
    identifier_ids.empty? ? text_matches : where(id: text_matches.select(:id)).or(where(id: identifier_ids))
  end

  def bookmarks_count
    if self.respond_to?(:bookmarks)
      self.bookmarks.length
    else
      0
    end
  end
end
