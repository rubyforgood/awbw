class AddFieldsToFaqs < ActiveRecord::Migration[4.2]
  def change
    add_column :faqs, :inactive, :boolean
    add_column :faqs, :ordering, :integer
  end
end
