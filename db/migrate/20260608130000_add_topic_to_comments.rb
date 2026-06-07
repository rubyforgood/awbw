class AddTopicToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :topic, :string
  end
end
