require "rails_helper"

RSpec.describe "Admin data health background jobs", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  describe "POST /admin/data_health/retry_interrupted_jobs" do
    let(:status) { instance_double(BackgroundJobsStatus, retry_interrupted!: 2) }

    before { allow(BackgroundJobsStatus).to receive(:new).and_return(status) }

    it "retries interrupted jobs for an admin" do
      allow(BackgroundJobsStatus).to receive(:available?).and_return(true)
      sign_in admin

      post admin_data_health_retry_interrupted_jobs_path

      expect(status).to have_received(:retry_interrupted!)
      expect(flash[:notice]).to eq("Retried 2 jobs.")
    end

    it "refuses a non-admin" do
      allow(BackgroundJobsStatus).to receive(:available?).and_return(true)
      sign_in user

      post admin_data_health_retry_interrupted_jobs_path

      expect(status).not_to have_received(:retry_interrupted!)
    end
  end

  describe "GET /admin/data_health" do
    it "explains there's nothing to check where jobs don't run through Solid Queue" do
      sign_in admin

      get admin_data_health_path

      expect(response.body).to include("Background jobs")
      expect(response.body).to include("nothing to check here")
    end
  end
end

RSpec.describe "Admin data health background jobs status", :solid_queue, type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    allow(BackgroundJobsStatus).to receive(:available?).and_return(true)
    allow(JobRunnerHealth).to receive_messages(alive?: false, last_worker_heartbeat_at: 3.hours.ago)
    sign_in admin
  end

  it "shows the runner as stopped, without a restart button" do
    get admin_data_health_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Not running")
    expect(response.body).not_to include("Restart app")
  end
end
