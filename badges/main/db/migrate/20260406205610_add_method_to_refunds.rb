class AddMethodToRefunds < ActiveRecord::Migration[8.1]
  def change
    add_column :refunds, :method, :string, null: false
  end
end
