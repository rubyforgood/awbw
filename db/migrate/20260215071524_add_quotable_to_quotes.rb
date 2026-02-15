class AddQuotableToQuotes < ActiveRecord::Migration[8.1]
  def change
    add_reference :quotes, :quotable, polymorphic: true, index: true
  end
end
