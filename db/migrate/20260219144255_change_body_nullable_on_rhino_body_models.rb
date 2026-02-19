class ChangeBodyNullableOnRhinoBodyModels < ActiveRecord::Migration[8.1]
  def up
    change_column_null :story_ideas, :body, true
    change_column_null :stories, :body, true
    change_column_null :community_news, :body, true
    change_column_null :resources, :body, true
    change_column_null :tutorials, :body, true
    change_column_null :workshop_variation_ideas, :body, true
    change_column_null :workshop_variations, :body, true
  end

  def down
    %i[story_ideas stories community_news resources tutorials workshop_variation_ideas workshop_variations].each do |table|
      ActiveRecord::Base.connection.execute("UPDATE #{table} SET body = '' WHERE body IS NULL")
      change_column_null table, :body, false
    end
  end
end
