class MigrateResourceTypes < ActiveRecord::Migration
  def change
    Resource.where(type: "TemplateAndHandout").update_all(type: "Template")
    Resource.where(type: "ToolkitAndForm").update_all(type: "Form")
  end
end
