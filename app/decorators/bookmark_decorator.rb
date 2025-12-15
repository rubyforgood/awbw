class BookmarkDecorator < ApplicationDecorator
  delegate :current_page, :total_pages, :limit_value
  decorates_association :bookmarkable

  def title
    "Bookmark of #{bookmarkable_class_name} ##{bookmarkable.id}"
  end

  def detail
    "Bookmarkable: #{bookmarkable_class_name} ##{bookmarkable.id} (#{bookmarkable.title})"
  end

  def breadcrumbs
    "#{bookmarks_link} >> #{bookmarkable_link}".html_safe
  end

  def content
    if bookmarkable_class_name == 'Workshop'
      h.render '/workshops/show', workshop: bookmarkable, sectors: bookmarkable.sectors,
                                       new_bookmark: bookmarkable.bookmarks.build,
                                       quotes: bookmarkable.quotes, leader_spotlights: bookmarkable.leader_spotlights,
                                       workshop_variations: bookmarkable.workshop_variations
    end
  end

  def bookmarkable_class_name
    bookmarkable.object.class.name
  end

  def bookmarks_link
    h.link_to 'My Bookmarks',h.bookmarks_path, class: 'underline'
  end

  def bookmarkable_link
    if bookmarkable_class_name == 'Workshop'
      bookmarkable.breadcrumb_link
    end
  end

  def bookmarkable_image_url(fallback: 'missing.png')
    if bookmarkable.respond_to?(:images) && bookmarkable.images.first&.file&.attached?
      Rails.application.routes.url_helpers.rails_blob_path(bookmarkable.images.first.file, only_path: true)
    elsif bookmarkable_type == "Workshop"
      ActionController::Base.helpers.asset_path("workshop_default.jpg")
    else
      ActionController::Base.helpers.asset_path(fallback)
    end
  end
end
