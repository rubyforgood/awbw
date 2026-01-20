class ConvertProjectUserPositionToTitle < ActiveRecord::Migration[8.1]
  def up
    # Map position enum values to human-readable titles
    # default: 0, liaison: 1, leader: 2, assistant: 3
    position_to_title = {
      0 => "default",
      1 => "liaison",
      2 => "leader",
      3 => "assistant"
    }

    # Update title from position where title is nil
    Affiliation.where(title: [ nil, "" ]).find_each do |affiliation|
      position_value = affiliation.read_attribute(:position)
      if position_value.present?
        title_value = position_to_title[position_value]
        affiliation.update_column(:title, title_value) if title_value
      end
    end

    # Remove the position column
    remove_column :affiliations, :position, :integer
  end

  def down
    # Add position column back
    add_column :affiliations, :position, :integer

    # Map titles back to position enum values
    title_to_position = {
      "default" => 0,
      "liaison" => 1,
      "leader" => 2,
      "assistant" => 3
    }

    # Restore position from title
    Affiliation.where.not(title: nil).find_each do |affiliation|
      position_value = title_to_position[affiliation.title]
      affiliation.update_column(:position, position_value) if position_value
    end
  end
end
