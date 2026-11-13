class DropNameFormatColumnDefaults < ActiveRecord::Migration[8.1]
  def up
    change_column_default :people, :display_name_preference, nil
    change_column_default :community_news, :author_credit_preference, nil
  end

  def down
    change_column_default :people, :display_name_preference, "first_name_last_initial"
    change_column_default :community_news, :author_credit_preference, "full_name"
  end
end
