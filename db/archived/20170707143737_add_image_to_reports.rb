class AddImageToReports < ActiveRecord::Migration[4.2]
  def change
    add_reference :images, :report, foreign_key: true
  end
end
