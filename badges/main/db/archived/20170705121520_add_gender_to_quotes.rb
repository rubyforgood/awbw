class AddGenderToQuotes < ActiveRecord::Migration
  def change
    add_column :quotes, :gender, :string, :limit => 1
  end
end
