class FixShareStoryOwnerType < ActiveRecord::Migration
  def up
    @reports = Report.where(owner_type: "Report", owner_id: 7)
    @reports.update_all(owner_type: "FormBuilder")
  end

  def down
    @reports = Report.where(owner_type: "FormBuilder", owner_id: 7)
    @reports.update_all(owner_type: "Report")
  end
end
