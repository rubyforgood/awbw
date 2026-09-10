class AddMissingFmArchiveTables < ActiveRecord::Migration[8.1]
  def up
    tables = {
      fm_ancillary_data: "RecordID",
      fm_art_purchases: "PurchaseID",
      fm_art_registries: "ItemID",
      fm_campaigns: "CampaignID",
      fm_committee_meetings: "CtMtgID",
      fm_committee_members: "CMRecID",
      fm_committees: "CommitteeID",
      fm_contacts: "ContactID",
      fm_donor_developers: "DonorDevRecID",
      fm_email_addresses: "EmailAddrsID",
      fm_exhibited_items: "RecordID",
      fm_form_fields: "FieldNo",
      fm_form_letters: "DocID",
      fm_forms_lists: "FormID",
      fm_form_submissions: "RecordID",
      fm_group_members: "RecordID",
      fm_groups: "GroupID",
      fm_invoices: "RecordID",
      fm_line_items: "ItemID",
      fm_match_donations: "RecordID",
      fm_people_to_organizations: "RecordID",
      fm_quotations: "RecordID",
      fm_reportings: "ReportID",
      fm_solicitations: "SolicitationID",
      fm_volunteers: "VolID",
      fm_workshops: "WorkshopID"
    }

    tables.each do |table_name, key_col|
      create_table table_name do |t|
        t.string :fm_id, null: false
        t.string :fm_key_name, null: false, default: key_col
        t.json :data, null: false
        t.timestamps
      end
      add_index table_name, :fm_id, unique: true
    end
  end

  def down
    %i[
      fm_ancillary_data fm_art_purchases fm_art_registries fm_campaigns
      fm_committee_meetings fm_committee_members fm_committees fm_contacts
      fm_donor_developers fm_email_addresses fm_exhibited_items fm_form_fields
      fm_form_letters fm_forms_lists fm_form_submissions fm_group_members
      fm_groups fm_invoices fm_line_items fm_match_donations
      fm_people_to_organizations fm_quotations fm_reportings fm_solicitations
      fm_volunteers fm_workshops
    ].each do |table_name|
      drop_table table_name if table_exists?(table_name)
    end
  end
end
