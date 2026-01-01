class CreateAssets < ActiveRecord::Migration[7.1]
  def change
    create_table :assets, id: :integer, charset: "utf8mb4", collation: "utf8mb4_unicode_ci" do |t|
      # Polymorphic owner
      t.integer :owner_id
      t.string  :owner_type

      # Optional reporting / grouping
      t.integer :report_id

      # STI
      t.string :type, null: false, default: "PrimaryAsset"

      # Indexes
      t.index :owner_id
      t.index :owner_type
      t.index :type

      t.timestamps
    end
  end
end
