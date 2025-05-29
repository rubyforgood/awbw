class AddAgeToQuotes < ActiveRecord::Migration[4.2]
  def change
    add_column :quotes, :age, :string
  end
end
