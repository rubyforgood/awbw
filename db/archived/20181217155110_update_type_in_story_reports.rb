class UpdateTypeInStoryReports < ActiveRecord::Migration[4.2]
  def self.up
    Report.where("owner_id = 7 AND type = 'Report'").update_all(type: "Story")
  end
end
