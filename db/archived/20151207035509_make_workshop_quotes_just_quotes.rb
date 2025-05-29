class MakeWorkshopQuotesJustQuotes < ActiveRecord::Migration[4.2]
  def change
    rename_table :workshop_quotes, :quotes
  end
end
