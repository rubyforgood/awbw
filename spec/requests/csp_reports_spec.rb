require "rails_helper"

RSpec.describe "CspReports", type: :request do
  let(:report) do
    {
      "csp-report" => {
        "document-uri" => "http://localhost/people/1/edit",
        "violated-directive" => "style-src-elem",
        "blocked-uri" => "inline"
      }
    }
  end

  describe "POST /csp-violation-report-endpoint" do
    it "accepts an unauthenticated report and returns 204" do
      post "/csp-violation-report-endpoint",
           params: report.to_json,
           headers: { "CONTENT_TYPE" => "application/csp-report" }

      expect(response).to have_http_status(:no_content)
    end

    it "logs the report payload" do
      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info).with(/CSP violation/)

      post "/csp-violation-report-endpoint",
           params: report.to_json,
           headers: { "CONTENT_TYPE" => "application/csp-report" }
    end

    it "does not fail on a malformed body" do
      post "/csp-violation-report-endpoint",
           params: "not json",
           headers: { "CONTENT_TYPE" => "application/csp-report" }

      expect(response).to have_http_status(:no_content)
    end
  end
end
