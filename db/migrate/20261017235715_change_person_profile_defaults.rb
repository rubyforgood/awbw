class ChangePersonProfileDefaults < ActiveRecord::Migration[8.1]
  HIDDEN_BY_DEFAULT = %i[profile_show_pronouns profile_show_phone profile_show_social_media].freeze

  def up
    change_column_default :people, :display_name_preference, from: nil, to: "first_name_last_initial"
    HIDDEN_BY_DEFAULT.each { |column| change_column_default :people, column, from: true, to: false }
  end

  def down
    change_column_default :people, :display_name_preference, from: "first_name_last_initial", to: nil
    HIDDEN_BY_DEFAULT.each { |column| change_column_default :people, column, from: false, to: true }
  end
end
