# frozen_string_literal: true

class AddTimeZoneToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :time_zone, :string, default: "Pacific Time (US & Canada)"
  end
end
