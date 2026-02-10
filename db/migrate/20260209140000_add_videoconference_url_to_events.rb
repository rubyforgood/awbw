# frozen_string_literal: true

class AddVideoconferenceUrlToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :videoconference_url, :string
  end
end
