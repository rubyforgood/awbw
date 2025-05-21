class AddAgeToQuotes < ActiveRecord::Migration
  def change
    add_column :quotes, :age, :string
  end
end
