class AddEventRegistrationToAffiliations < ActiveRecord::Migration[8.1]
  # Provenance link: the registration that auto-minted this affiliation. NULL means
  # it was created manually/historically (not through CreateFromRegistration), which
  # is how facilitator reconciliation tells auto-minted rows from ones to leave alone.
  def up
    return if column_exists?(:affiliations, :event_registration_id)

    add_reference :affiliations, :event_registration, null: true, index: true,
                  foreign_key: { on_delete: :nullify }
  end

  def down
    remove_reference :affiliations, :event_registration, foreign_key: true if column_exists?(:affiliations, :event_registration_id)
  end
end
