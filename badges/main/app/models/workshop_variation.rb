class WorkshopVariation < ApplicationRecord
  belongs_to :workshop

  rails_admin do
    field :name
    field :ordering
    field :inactive
    field :code, :ck_editor

    exclude_fields :workshop
  end
end
