class MakeInactiveDefaultToTrueOnQuotes < ActiveRecord::Migration
  def up
    change_column :quotes, :inactive, :boolean, default: true
  end

  def down
    change_column :quotes, :inactive, :boolean, default: false
  end

end
