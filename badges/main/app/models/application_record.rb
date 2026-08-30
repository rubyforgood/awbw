class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  include AhoyTrackable
  include UserStampable

  def bookmarks_count
    if self.respond_to?(:bookmarks)
      self.bookmarks.length
    else
      0
    end
  end
end
