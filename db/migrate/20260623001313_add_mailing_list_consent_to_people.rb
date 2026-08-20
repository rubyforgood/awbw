class AddMailingListConsentToPeople < ActiveRecord::Migration[8.1]
  def up
    add_column :people, :mailing_list_consent_at, :datetime
    add_column :people, :mailing_list_consent_source, :string
  end

  def down
    remove_column :people, :mailing_list_consent_at, if_exists: true
    remove_column :people, :mailing_list_consent_source, if_exists: true
  end
end
