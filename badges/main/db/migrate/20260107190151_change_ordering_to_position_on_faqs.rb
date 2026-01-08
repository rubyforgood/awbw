class ChangeOrderingToPositionOnFaqs < ActiveRecord::Migration[8.1]
  def change
    rename_column :faqs, :ordering, :position
    change_column_null :faqs, :position, false
  end
end
