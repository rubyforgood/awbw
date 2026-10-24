class BookmarkDecorator < ApplicationDecorator
  delegate :current_page, :total_pages, :limit_value
  decorates_association :bookmarkable

  def title
    "Bookmark of #{bookmarkable_class_name} ##{bookmarkable.id}"
  end

  def detail(length: nil)
    "Bookmarkable: #{bookmarkable_class_name} ##{bookmarkable.id} (#{bookmarkable.title})"
  end

  def display_image
    bookmarkable.decorate.display_image
  end

  def bookmarkable_class_name
    bookmarkable.object.class.name
  end
end
