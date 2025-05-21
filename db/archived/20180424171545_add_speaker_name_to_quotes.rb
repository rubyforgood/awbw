class AddSpeakerNameToQuotes < ActiveRecord::Migration
  def change
    add_column :quotes, :speaker_name, :string
  end
end
