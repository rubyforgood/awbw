class MakeInactiveDefaultToTrueOnQuotes < ActiveRecord::Migration[4.2]
  def up
    change_column :quotes, :inactive, :boolean, default: true
  end

  def down
    change_column :quotes, :inactive, :boolean, default: false
  end

end
