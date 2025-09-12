class MakeWorkshopQuotesJustQuotes < ActiveRecord::Migration
  def change
    rename_table :workshop_quotes, :quotes
  end
end
