class FixEmtpyColonTimeFrameWorkshop < ActiveRecord::Migration
  def change
    Workshop.where(timeframe: ":").update_all(timeframe: nil)
  end
end
