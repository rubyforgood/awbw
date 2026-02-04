module Featureable
  extend ActiveSupport::Concern

  included do
    scope :featured, -> { published.where(featured: true) }
    scope :publicly_featured, -> { published.where(publicly_featured: true, publicly_visible: true) }
  end
end
