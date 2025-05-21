class AddFieldsToFaqs < ActiveRecord::Migration
  def change
    add_column :faqs, :inactive, :boolean
    add_column :faqs, :ordering, :integer
  end
end
