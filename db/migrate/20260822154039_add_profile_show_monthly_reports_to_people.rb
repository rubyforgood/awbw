class AddProfileShowMonthlyReportsToPeople < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:people, :profile_show_monthly_reports)
      add_column :people, :profile_show_monthly_reports, :boolean, default: true, null: false
    end
  end

  def down
    remove_column :people, :profile_show_monthly_reports, if_exists: true
  end
end
