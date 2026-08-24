class RemoveMailingListConsentFromPeople < ActiveRecord::Migration[8.0]
  def up
    remove_column :people, :mailing_list_consent_at, if_exists: true
    remove_column :people, :mailing_list_consent_source, if_exists: true
  end

  def down
    add_column :people, :mailing_list_consent_at, :datetime unless column_exists?(:people, :mailing_list_consent_at)
    add_column :people, :mailing_list_consent_source, :string unless column_exists?(:people, :mailing_list_consent_source)
  end
end
