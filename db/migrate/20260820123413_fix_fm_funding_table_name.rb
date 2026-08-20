class FixFmFundingTableName < ActiveRecord::Migration[8.1]
  def change
    rename_table :fm_funding, :fm_fundings
  end
end
