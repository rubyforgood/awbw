class AddSpeakerNameToQuotes < ActiveRecord::Migration[4.2]
  def change
    add_column :quotes, :speaker_name, :string
  end
end
