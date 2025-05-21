class UpdateTypeInStoryReports < ActiveRecord::Migration
  def self.up
    Report.where("owner_id = 7 AND type = 'Report'").update_all(type: "Story")
  end
end
