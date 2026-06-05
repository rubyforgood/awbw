require "rails_helper"

RSpec.describe "/monthly_reports", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:turbo_headers) { { "Turbo-Frame" => "monthly_reports_results" } }

  before { sign_in admin }

  describe "GET /index" do
    it "renders a successful response" do
      get monthly_reports_url
      expect(response).to be_successful
    end

    it "lists monthly reports across organizations when no filter applied" do
      create(:monthly_report, organization: organization, date: Date.new(2026, 4, 1))
      create(:monthly_report, organization: other_organization, date: Date.new(2026, 3, 1))

      get monthly_reports_url, headers: turbo_headers
      expect(response.body).to include("Apr 2026")
      expect(response.body).to include("Mar 2026")
    end

    it "filters by organization_id when provided" do
      create(:monthly_report, organization: organization, date: Date.new(2026, 4, 1))
      create(:monthly_report, organization: other_organization, date: Date.new(2026, 3, 1))

      get monthly_reports_url(organization_id: organization.id), headers: turbo_headers
      expect(response.body).to include("Apr 2026")
      expect(response.body).not_to include("Mar 2026")
    end

    it "still supports the nested organization route" do
      create(:monthly_report, organization: organization, date: Date.new(2026, 4, 1))
      create(:monthly_report, organization: other_organization, date: Date.new(2026, 3, 1))

      get organization_monthly_reports_url(organization), headers: turbo_headers
      expect(response).to be_successful
      expect(response.body).to include("Apr 2026")
      expect(response.body).not_to include("Mar 2026")
    end

    it "shows org-specific empty state when an organization is set" do
      get organization_monthly_reports_url(organization), headers: turbo_headers
      expect(response.body).to include("No monthly reports for this organization yet")
    end

    it "shows generic empty state when no organization is set" do
      get monthly_reports_url, headers: turbo_headers
      expect(response.body).to include("No monthly reports found")
    end
  end

  describe "GET /show" do
    let(:report) { create(:monthly_report, organization: organization, date: Date.new(2026, 4, 1)) }

    it "renders a successful response" do
      get monthly_report_url(report)
      expect(response).to be_successful
    end

    it "renders sections for associated data" do
      get monthly_report_url(report)
      expect(response.body).to include("Submitted by")
      expect(response.body).to include("Organization")
      expect(response.body).to include("Workshop")
      expect(response.body).to include("Uploads")
    end
  end

  describe "removed REST actions" do
    it "does not expose new_monthly_report_path" do
      expect(Rails.application.routes.url_helpers).not_to respond_to(:new_monthly_report_path)
    end

    it "does not expose edit_monthly_report_path" do
      expect(Rails.application.routes.url_helpers).not_to respond_to(:edit_monthly_report_path)
    end

    it "does not route POST /monthly_reports" do
      expect { Rails.application.routes.recognize_path("/monthly_reports", method: :post) }
        .to raise_error(ActionController::RoutingError)
    end

    it "does not route PATCH /monthly_reports/:id" do
      expect { Rails.application.routes.recognize_path("/monthly_reports/1", method: :patch) }
        .to raise_error(ActionController::RoutingError)
    end

    it "does not route DELETE /monthly_reports/:id" do
      expect { Rails.application.routes.recognize_path("/monthly_reports/1", method: :delete) }
        .to raise_error(ActionController::RoutingError)
    end
  end
end
