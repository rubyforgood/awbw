class CategorizableItem < ApplicationRecord
  # Associations
  belongs_to :categorizable, polymorphic: true
  belongs_to :category

  # Attr Accessor
  attr_accessor :_create

  # Rails Admin
  rails_admin do
    exclude_fields :legacy
  end
end
