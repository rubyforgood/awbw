# frozen_string_literal: true

class AddLocationToEvents < ActiveRecord::Migration[8.1]
  def change
    add_reference :events,
                  :location,
                  foreign_key: true,
                  type: :integer
  end
end
