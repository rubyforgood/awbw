class AddGrantToScholarships < ActiveRecord::Migration[8.1]
  def up
    add_reference :scholarships, :grant, null: true, foreign_key: true unless column_exists?(:scholarships, :grant_id)
  end

  def down
    remove_foreign_key :scholarships, :grants if foreign_key_exists?(:scholarships, :grants)
    remove_reference :scholarships, :grant if column_exists?(:scholarships, :grant_id)
  end
end
