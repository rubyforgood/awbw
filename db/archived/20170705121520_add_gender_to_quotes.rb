class AddGenderToQuotes < ActiveRecord::Migration[4.2]
  def change
    add_column :quotes, :gender, :string, :limit => 1
  end
end
