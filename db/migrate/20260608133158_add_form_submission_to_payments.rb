class AddFormSubmissionToPayments < ActiveRecord::Migration[8.1]
  def change
    add_reference :payments, :form_submission, null: true, foreign_key: true
  end
end
