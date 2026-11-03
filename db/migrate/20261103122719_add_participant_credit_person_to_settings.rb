class AddParticipantCreditPersonToSettings < ActiveRecord::Migration[8.1]
  def up
    add_reference :settings, :participant_credit_person unless column_exists?(:settings, :participant_credit_person_id)
    unless foreign_key_exists?(:settings, column: :participant_credit_person_id)
      add_foreign_key :settings, :people, column: :participant_credit_person_id, on_delete: :nullify
    end
  end

  def down
    remove_foreign_key :settings, column: :participant_credit_person_id if foreign_key_exists?(:settings, column: :participant_credit_person_id)
    remove_reference :settings, :participant_credit_person if column_exists?(:settings, :participant_credit_person_id)
  end
end
