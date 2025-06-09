class SetHasAttachmentMonthlyReports < ActiveRecord::Migration
  def change
    MonthlyReport.find_each do |mr|
      mr.send :set_has_attachament
      mr.save
    end
  end
end
