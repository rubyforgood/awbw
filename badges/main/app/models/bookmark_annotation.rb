class BookmarkAnnotation < ApplicationRecord
  belongs_to :bookmark

  def content_with_id
    {id: id}.merge(JSON.parse(annotation))
  end
end
