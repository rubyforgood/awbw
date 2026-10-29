require "rails_helper"

RSpec.describe "Health checks", type: :request do
  describe "GET /up/jobs" do
    it "answers OK without signing in while the job runner is checking in" do
      allow(JobRunnerHealth).to receive(:alive?).and_return(true)

      get "/up/jobs"

      expect(response).to have_http_status(:ok)
    end

    it "answers 503 once the job runner stops checking in" do
      allow(JobRunnerHealth).to receive(:alive?).and_return(false)

      get "/up/jobs"

      expect(response).to have_http_status(:service_unavailable)
    end
  end
end
