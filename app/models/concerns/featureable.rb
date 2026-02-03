module Featureable
  extend ActiveSupport::Concern

  included do
    scope :featured, -> { where(featured: true, inactive: false) }
    scope :public_featured, -> { where(public_featured: true, public: true, inactive: false) }
  end
end
