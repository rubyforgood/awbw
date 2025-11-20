class ChangeStoryReferences < ActiveRecord::Migration[8.1]
  def change
    change_column_null :stories, :project_id, true
    change_column_null :stories, :workshop_id, true
  end
end
