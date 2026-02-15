# frozen_string_literal: true

class AddTimeZoneToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :time_zone, :string, default: "Pacific Time (US & Canada)"
  end
end
