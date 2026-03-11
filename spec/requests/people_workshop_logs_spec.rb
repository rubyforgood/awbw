require "rails_helper"

RSpec.describe "People#workshop_logs", type: :request do
  let(:windows_type) { create(:windows_type, short_name: "Combined") }
  let(:organization) { create(:organization, name: "Test Org", windows_type_id: windows_type.id) }
  let(:workshop_a) { create(:workshop, :published, title: "Workshop A", windows_type: windows_type) }
  let(:workshop_b) { create(:workshop, :published, title: "Workshop B", windows_type: windows_type) }
  let(:owner) { create(:user) }
  let(:person) { create(:person, user: owner, profile_show_workshop_logs: true) }

  before do
    create(:affiliation, person: person, organization: organization)
  end

  def create_log(workshop, date:)
    create(:workshop_log,
      owner: workshop,
      workshop: workshop,
      organization_id: organization.id,
      created_by_id: owner.id,
      date: date,
      adults_first_time: 1,
      adults_ongoing: 2)
  end

  describe "GET /people/:id/workshop_logs" do
    context "as the owner" do
      before { sign_in owner }

      it "renders the workshop logs page" do
        create_log(workshop_a, date: 1.day.ago)
        get workshop_logs_person_path(person)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Workshop Logs for")
      end

      it "groups logs by workshop" do
        create_log(workshop_a, date: 1.day.ago)
        create_log(workshop_a, date: 2.days.ago)
        create_log(workshop_b, date: 3.days.ago)
        get workshop_logs_person_path(person)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Workshop A")
        expect(response.body).to include("Workshop B")
      end

      it "filters by workshop_id" do
        create_log(workshop_a, date: 1.day.ago)
        create_log(workshop_b, date: 2.days.ago)
        get workshop_logs_person_path(person, workshop_id: workshop_a.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Workshop A")
      end

      it "filters by external_title" do
        log = create_log(workshop_a, date: 1.day.ago)
        log.update!(workshop_id: nil, external_workshop_title: "Outside Art Class")
        get workshop_logs_person_path(person, external_title: "Outside Art Class")
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Outside Art Class")
      end
    end

    context "as an admin" do
      let(:admin) { create(:user, :admin) }

      before { sign_in admin }

      it "renders the workshop logs page" do
        create_log(workshop_a, date: 1.day.ago)
        get workshop_logs_person_path(person)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as a non-owner regular user" do
      let(:other_user) { create(:user) }

      before { sign_in other_user }

      it "denies access" do
        get workshop_logs_person_path(person)
        expect(response).to redirect_to(root_path)
      end
    end

    context "when not signed in" do
      it "denies access" do
        get workshop_logs_person_path(person)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
