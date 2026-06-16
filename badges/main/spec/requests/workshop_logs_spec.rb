require "rails_helper"

RSpec.describe "/workshop_logs", type: :request do
  include ActiveJob::TestHelper

  let(:user)         { create(:user) }
  let(:windows_type) { create(:windows_type) }
  let(:workshop)     { create(:workshop) }
  let(:organization) { create(:organization) }

  let(:valid_attributes) do
    {
      workshop_held_on: Date.current,
      workshop_id: workshop.id,
      organization_id: organization.id,
      windows_type_id: windows_type.id,
      created_by_id: user.id,

      children_first_time: 3,
      children_ongoing: 5,
      teens_first_time: 2,
      teens_ongoing: 4,
      adults_first_time: 1,
      adults_ongoing: 6
    }
  end

  let(:external_title_attributes) do
    {
      workshop_held_on: Date.current,
      workshop_id: nil,
      external_workshop_title: "Community Art Workshop",
      organization_id: organization.id,
      windows_type_id: windows_type.id,
      created_by_id: user.id,
      children_first_time: 1,
      children_ongoing: 2,
      teens_first_time: 0,
      teens_ongoing: 0,
      adults_first_time: 0,
      adults_ongoing: 3
    }
  end

  let(:invalid_attributes) do
    {
      workshop_held_on: nil,
      workshop_id: nil
    }
  end

  before do
    sign_in user
    clear_enqueued_jobs
  end

  describe "GET /show" do
    it "renders the organization as plain text and the creator as a link (non-admin)" do
      person = create(:person, user: user)
      create(:affiliation, person: person, organization: organization)
      workshop_log = create(:workshop_log, created_by: user, organization: organization,
                            workshop: workshop, windows_type: windows_type, workshop_held_on: 1.day.ago)

      get workshop_log_path(workshop_log)

      page = Capybara.string(response.body)
      expect(page).to have_text(organization.name)
      expect(page).not_to have_link(organization.name)
      expect(page).to have_link(user.name, href: person_path(person))
    end

    it "renders the creator as plain text when they have no person record" do
      workshop_log = create(:workshop_log, created_by: user, organization: organization,
                            workshop: workshop, windows_type: windows_type, workshop_held_on: 1.day.ago)

      get workshop_log_path(workshop_log)

      page = Capybara.string(response.body)
      expect(page).to have_text(user.name)
      expect(page).not_to have_link(user.name)
    end

    it "shows the external title in the heading and beside the Workshop label when there is no workshop" do
      workshop_log = create(:workshop_log, created_by: user, organization: organization,
                            workshop: nil, windows_type: windows_type,
                            external_workshop_title: "Community Mural Project", workshop_held_on: 1.day.ago)

      get workshop_log_path(workshop_log)

      page = Capybara.string(response.body)
      expect(page).to have_css("h1", text: "Community Mural Project")
      workshop_div = page.find("span", text: "Workshop:").ancestor("div", match: :first)
      expect(workshop_div).to have_text("Community Mural Project")
    end

    it "shows the workshop name in the heading and both the workshop and external title when both are present" do
      titled_workshop = create(:workshop, :published, title: "Healing Through Art", windows_type: windows_type)
      workshop_log = create(:workshop_log, created_by: user, organization: organization,
                            workshop: titled_workshop, windows_type: windows_type,
                            external_workshop_title: "Guest-led Session", workshop_held_on: 1.day.ago)

      get workshop_log_path(workshop_log)

      page = Capybara.string(response.body)
      expect(page).to have_css("h1", text: "Healing Through Art")
      workshop_div = page.find("span", text: "Workshop:").ancestor("div", match: :first)
      expect(workshop_div).to have_text("Healing Through Art")
      expect(workshop_div).to have_text("Guest-led Session")
    end

    context "as an admin" do
      let(:admin) { create(:user, :admin) }
      before { sign_in admin }

      it "renders the organization and creator as links" do
        person = create(:person, user: user)
        create(:affiliation, person: person, organization: organization)
        workshop_log = create(:workshop_log, created_by: user, organization: organization,
                              workshop: workshop, windows_type: windows_type, workshop_held_on: 1.day.ago)

        get workshop_log_path(workshop_log)

        page = Capybara.string(response.body)
        expect(page).to have_link(organization.name, href: organization_path(organization))
        expect(page).to have_link(user.name, href: person_path(person))
      end
    end
  end

  describe "GET /index" do
    it "loads the index page successfully" do
      get workshop_logs_path
      expect(response).to have_http_status(:success)
    end

    it "filters workshop logs by workshop_id" do
      workshop_log = create(:workshop_log, valid_attributes.merge(children_first_time: 999))
      other_workshop = create(:workshop)
      other_log = create(:workshop_log, valid_attributes.merge(workshop_id: other_workshop.id, children_first_time: 111))

      get workshop_logs_path, params: { workshop_id: workshop.id }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("workshop_log_#{workshop_log.id}")
      expect(response.body).not_to include("workshop_log_#{other_log.id}")
    end

    context "colleague workshop log visibility" do
      it "shows workshop logs from colleagues in the same organization" do
        shared_org = create(:organization, name: "Shared Org")
        person = create(:person, user: user)
        create(:affiliation, person: person, organization: shared_org)

        colleague = create(:user)
        colleague_person = create(:person, user: colleague)
        create(:affiliation, person: colleague_person, organization: shared_org)

        colleague_log = create(:workshop_log, valid_attributes.merge(
          created_by_id: colleague.id,
          organization_id: shared_org.id
        ))

        get workshop_logs_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("workshop_log_#{colleague_log.id}")
      end

      it "does not show workshop logs from unaffiliated organizations" do
        my_org = create(:organization, name: "My Org")
        person = create(:person, user: user)
        create(:affiliation, person: person, organization: my_org)

        other_org = create(:organization, name: "Other Org")
        stranger = create(:user)
        stranger_person = create(:person, user: stranger)
        create(:affiliation, person: stranger_person, organization: other_org)

        stranger_log = create(:workshop_log, valid_attributes.merge(
          created_by_id: stranger.id,
          organization_id: other_org.id
        ))

        get workshop_logs_path

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include("workshop_log_#{stranger_log.id}")
      end
    end

    context "person filtering" do
      it "shows only affiliated colleagues in the person dropdown for non-admin users" do
        shared_org = create(:organization, name: "Shared Org")
        person = create(:person, user: user, first_name: "Current", last_name: "Userface")
        create(:affiliation, person: person, organization: shared_org)

        colleague = create(:user)
        colleague_person = create(:person, user: colleague, first_name: "Colleague", last_name: "Personface")
        create(:affiliation, person: colleague_person, organization: shared_org)

        unaffiliated_org = create(:organization, name: "Unaffiliated Org")
        stranger = create(:user)
        stranger_person = create(:person, user: stranger, first_name: "Stranger", last_name: "Dangerface")
        create(:affiliation, person: stranger_person, organization: unaffiliated_org)

        get workshop_logs_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Colleague Personface")
        expect(response.body).not_to include("Stranger Dangerface")
      end

      it "shows all people with access for admin users" do
        admin = create(:user, :admin)
        sign_in admin

        org_a = create(:organization)
        person_a = create(:person, user: create(:user), first_name: "Alpha", last_name: "Userton")
        create(:affiliation, person: person_a, organization: org_a)

        org_b = create(:organization)
        person_b = create(:person, user: create(:user), first_name: "Beta", last_name: "Userton")
        create(:affiliation, person: person_b, organization: org_b)

        get workshop_logs_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Alpha Userton")
        expect(response.body).to include("Beta Userton")
      end
    end

    context "organization filtering" do
      it "shows only affiliated organizations for non-admin users" do
        person = create(:person, user: user)
        affiliated_org = create(:organization, name: "Affiliated Org")
        unaffiliated_org = create(:organization, name: "Unaffiliated Org")
        create(:affiliation, person: person, organization: affiliated_org)

        get workshop_logs_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Affiliated Org")
        expect(response.body).not_to include("Unaffiliated Org")
      end

      it "includes organizations from inactive affiliations for non-admin users" do
        person = create(:person, user: user)
        inactive_org = create(:organization, name: "Inactive Affiliation Org")
        create(:affiliation, person: person, organization: inactive_org, inactive: true)

        get workshop_logs_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Inactive Affiliation Org")
      end

      it "shows all organizations for admin users" do
        admin = create(:user, :admin)
        sign_in admin
        org_a = create(:organization, name: "Org Alpha")
        org_b = create(:organization, name: "Org Beta")

        get workshop_logs_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Org Alpha")
        expect(response.body).to include("Org Beta")
      end
    end

    # TODO use action policy to filter
    xit "populates workshops dropdown with only workshops from visible logs" do
      visible_workshop = create(:workshop)
      hidden_workshop  = create(:workshop, published: false)
      unassigned_workshop  = create(:workshop)
      unassigned_hidden_workshop  = create(:workshop, published: false)

      create(:workshop_log, workshop: visible_workshop)
      create(:workshop_log, workshop: hidden_workshop)

      get workshop_logs_path

      expect(response).to have_http_status(:success)

      expect(response.body).to include(visible_workshop.name)
      expect(response.body).to include(hidden_workshop.name)
      expect(response.body).not_to include(unassigned_workshop.name)
      expect(response.body).not_to include(unassigned_hidden_workshop.name)
    end
  end

  describe "GET /new" do
    let!(:combined_windows_type) { create(:windows_type, :combined) }
    let!(:form_builder) do
      fb = FormBuilder.create!(windows_type_id: combined_windows_type.id, name: "Combined form")
      fb.forms.create!
      fb
    end

    context "organization filtering" do
      it "shows only affiliated organizations for non-admin users" do
        person = create(:person, user: user)
        affiliated_org = create(:organization, name: "Affiliated Form Org")
        unaffiliated_org = create(:organization, name: "Unaffiliated Form Org")
        create(:affiliation, person: person, organization: affiliated_org)
        create(:affiliation, person: person, organization: create(:organization, name: "Second Affiliated Org"))

        get new_workshop_log_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Affiliated Form Org")
        expect(response.body).to include("Second Affiliated Org")
        expect(response.body).not_to include("Unaffiliated Form Org")
      end

      it "shows all organizations for admin users" do
        admin = create(:user, :admin)
        sign_in admin
        org_a = create(:organization, name: "Admin Form Org A")
        org_b = create(:organization, name: "Admin Form Org B")

        get new_workshop_log_path

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Admin Form Org A")
        expect(response.body).to include("Admin Form Org B")
      end
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a WorkshopLog" do
        expect {
          post workshop_logs_path, params: {
            workshop_log: valid_attributes
          }
        }.to change(WorkshopLog, :count).by(1)

        expect(response).to have_http_status(:redirect)
      end

      it "creates a WorkshopLog with external_workshop_title and no workshop" do
        expect {
          post workshop_logs_path, params: {
            workshop_log: external_title_attributes
          }
        }.to change(WorkshopLog, :count).by(1)

        log = WorkshopLog.last
        expect(log.workshop_id).to be_nil
        expect(log.external_workshop_title).to eq("Community Art Workshop")
        expect(response).to have_http_status(:redirect)
      end

      it "creates admin and submitter notifications and enqueues mail" do
        expect {
          post workshop_logs_path, params: {
            workshop_log: valid_attributes
          }
        }.to change(Notification, :count).by(2)

        workshop_log = WorkshopLog.last
        notifications = Notification.where(noticeable: workshop_log).order(:id)

        admin_notification = notifications.find_by(kind: "workshop_log_submitted_fyi")
        expect(admin_notification.recipient_role).to eq("admin")

        submitter_notification = notifications.find_by(kind: "workshop_log_submitted")
        expect(submitter_notification.recipient_role).to eq("person")
        expect(submitter_notification.recipient_email).to eq(user.email)

        expect(enqueued_jobs.map { |j| j[:job] })
          .to include(NotificationMailerJob)
      end
    end

    context "with invalid parameters" do
      it "does not create a WorkshopLog" do
        expect {
          post workshop_logs_path, params: {
            workshop_log: invalid_attributes
          }
        }.not_to change(WorkshopLog, :count)
      end

      xit "renders an unprocessable response" do
        post workshop_logs_path, params: {
          workshop_log: invalid_attributes
        }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /destroy" do
    it "destroys the workshop log and redirects to index" do
      workshop_log = create(:workshop_log, valid_attributes)

      expect {
        delete workshop_log_path(workshop_log)
      }.to change(WorkshopLog, :count).by(-1)

      expect(response).to redirect_to(workshop_logs_path)
    end

    it "preserves created_by_id param in redirect when present" do
      workshop_log = create(:workshop_log, valid_attributes)

      delete workshop_log_path(workshop_log), params: { created_by_id: user.id }

      expect(response).to redirect_to(workshop_logs_path(created_by_id: user.id))
    end

    it "does not allow destroying another user's workshop log" do
      other_user = create(:user)
      workshop_log = create(:workshop_log, valid_attributes.merge(created_by_id: other_user.id))

      expect {
        delete workshop_log_path(workshop_log)
      }.not_to change(WorkshopLog, :count)
    end

    it "allows admin to destroy any workshop log" do
      admin = create(:user, :admin)
      sign_in admin
      workshop_log = create(:workshop_log, valid_attributes)

      expect {
        delete workshop_log_path(workshop_log)
      }.to change(WorkshopLog, :count).by(-1)

      expect(response).to redirect_to(workshop_logs_path)
    end
  end
end
