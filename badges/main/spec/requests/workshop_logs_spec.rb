require "rails_helper"

RSpec.describe "/workshop_logs", type: :request do
  include ActiveJob::TestHelper

  let(:user)         { create(:user) }
  let(:windows_type) { create(:windows_type) }
  let(:workshop)     { create(:workshop) }
  let(:project)      { create(:project) }

  let(:valid_attributes) do
    {
      date: Date.current,
      workshop_id: workshop.id,
      project_id: project.id,
      windows_type_id: windows_type.id,
      user_id: user.id,

      children_first_time: 3,
      children_ongoing: 5,
      teens_first_time: 2,
      teens_ongoing: 4,
      adults_first_time: 1,
      adults_ongoing: 6
    }
  end

  let(:invalid_attributes) do
    {
      date: nil,
      workshop_id: nil
    }
  end

  before do
    sign_in user
    clear_enqueued_jobs
  end

  describe "GET /index" do
    it "loads the index page successfully" do
      get workshop_logs_path
      expect(response).to have_http_status(:success)
    end

    it "filters workshop logs by workshop_id" do
      workshop_log = create(:workshop_log, valid_attributes)
      other_workshop = create(:workshop)
      other_log = create(:workshop_log, valid_attributes.merge(workshop_id: other_workshop.id))

      get workshop_logs_path, params: { workshop_id: workshop.id }

      expect(response).to have_http_status(:success)
      expect(response.body).to include(workshop_log.workshop.name)
      expect(response.body).not_to include(other_log.workshop.name)
    end

    it "populates workshops dropdown with only workshops from visible logs" do
      visible_workshop = create(:workshop)
      hidden_workshop  = create(:workshop, inactive: true)
      unassigned_workshop  = create(:workshop)
      unassigned_hidden_workshop  = create(:workshop, inactive: true)

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

      it "creates an FYI notification and enqueues mail" do
        expect {
          post workshop_logs_path, params: {
            workshop_log: valid_attributes
          }
        }.to change(Notification, :count).by(1)

        notification = Notification.last
        workshop_log = WorkshopLog.last

        expect(notification.kind).to eq("workshop_log_submitted_fyi")
        expect(notification.noticeable).to eq(workshop_log)
        expect(notification.recipient_role).to eq("admin")

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
end
