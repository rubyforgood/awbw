class AddImageToReports < ActiveRecord::Migration
  def change
    add_reference :images, :report, foreign_key: true
  end
end
