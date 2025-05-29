class FixEmtpyColonTimeFrameWorkshop < ActiveRecord::Migration[4.2]
  def change
    Workshop.where(timeframe: ":").update_all(timeframe: nil)
  end
end
