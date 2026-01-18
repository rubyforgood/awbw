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
