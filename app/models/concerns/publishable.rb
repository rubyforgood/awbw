module Publishable
  extend ActiveSupport::Concern

  included do
    scope :published, ->(flag = nil) { !flag.to_s.present? ?
      where(published: true) : where(published: ActiveModel::Type::Boolean.new.cast(flag)) }

    scope :published_search, ->(published_search) { published_search.present? ? published(published_search) : all }

    if column_names.include?("publicly_visible")
      scope :publicly_visible, -> { published.where(publicly_visible: true) }
    end
  end
end
