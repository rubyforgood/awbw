module Featureable
  extend ActiveSupport::Concern

  included do
    scope :featured, -> { published.where(featured: true) }
    scope :publicly_featured, -> { published.publicly_visible.where(publicly_featured: true) }
    scope :featured_or_publicly_featured, -> { featured.or(publicly_featured) }
  end
end
