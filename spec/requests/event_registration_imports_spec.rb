require "rails_helper"

RSpec.describe "Event registration imports", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:event) { create(:event) }

  before do
    create(:organization, name: "A New Leaf")
    form = create(:form, name: "Registration form")
    create(:event_form, event: event, form: form, role: "registration")
    %w[first_name last_name primary_email organization_name].each do |identifier|
      create(:form_field, form: form, field_identifier: identifier)
    end
  end

  let(:csv) { fixture_file_upload("spec/fixtures/files/event_registrants_import.csv", "text/csv") }

  def signed_blob
    ActiveStorage::Blob.create_and_upload!(
      io: Rails.root.join("spec/fixtures/files/event_registrants_import.csv").open,
      filename: "event_registrants_import.csv",
      content_type: "text/csv"
    ).signed_id
  end

  describe "GET /event_registrations/import/new" do
    it "renders the upload form for admins" do
      sign_in admin
      get new_event_registration_import_path

      expect(response).to be_successful
      expect(response.body).to include("Import registrants")
    end

    it "redirects non-admins" do
      sign_in regular_user
      get new_event_registration_import_path

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /event_registrations/import" do
    before { sign_in admin }

    it "renders a preview without writing anything" do
      expect {
        post event_registration_import_path, params: { event_id: event.id, file: csv }
      }.not_to change(Person, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Preview import")
    end

    it "re-renders the form when no event is chosen" do
      post event_registration_import_path, params: { file: csv }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Choose an event")
    end

    it "re-renders the form when no file is chosen" do
      post event_registration_import_path, params: { event_id: event.id }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Choose a CSV file")
    end

    it "blocks an event with no registration form" do
      formless = create(:event)
      post event_registration_import_path, params: { event_id: formless.id, file: csv }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("no registration form")
    end

    it "is forbidden for non-admins" do
      sign_in regular_user
      post event_registration_import_path, params: { event_id: event.id, file: csv }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /event_registrations/import/confirm" do
    before { sign_in admin }

    it "creates attended registrations and redirects with a notice" do
      expect {
        post confirm_event_registration_import_path,
             params: { signed_id: signed_blob, event_id: event.id }
      }.to change(Person, :count).by(3).and change { event.event_registrations.count }.by(3)

      expect(event.event_registrations.pluck(:status).uniq).to eq([ "attended" ])
      expect(response).to redirect_to(event_registrations_path(event_id: event.id, admin: true))
      expect(flash[:notice]).to match(/3 attended registrations created/)
    end

    it "redirects with an alert when the upload is gone" do
      post confirm_event_registration_import_path,
           params: { signed_id: "bogus", event_id: event.id }

      expect(response).to redirect_to(new_event_registration_import_path)
      expect(flash[:alert]).to match(/no longer available/i)
    end

    it "is forbidden for non-admins" do
      sign_in regular_user
      post confirm_event_registration_import_path,
           params: { signed_id: signed_blob, event_id: event.id }

      expect(response).to redirect_to(root_path)
    end
  end
end
