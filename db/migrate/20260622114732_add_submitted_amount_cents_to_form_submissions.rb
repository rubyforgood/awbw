class AddSubmittedAmountCentsToFormSubmissions < ActiveRecord::Migration[8.0]
  def up
    add_column :form_submissions, :submitted_amount_cents, :integer
  end

  def down
    remove_column :form_submissions, :submitted_amount_cents, if_exists: true
  end
end
