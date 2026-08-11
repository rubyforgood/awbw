require "rails_helper"

RSpec.describe LinkedinAddToProfileUrl do
  def params_from(url)
    Rack::Utils.parse_query(url.split("?", 2).last)
  end

  let(:base_args) do
    {
      name: "Facilitator Training",
      issued_on: Date.new(2026, 8, 1),
      cert_url: "https://example.test/credential/abc",
      cert_id: "abc",
      organization_name: "A Window Between Worlds"
    }
  end

  it "builds the Add-to-Profile deep link with the certification fields" do
    url = described_class.new(**base_args).to_s

    expect(url).to start_with("https://www.linkedin.com/profile/add?")
    expect(params_from(url)).to include(
      "startTask" => "CERTIFICATION_NAME",
      "name" => "Facilitator Training",
      "issueYear" => "2026",
      "issueMonth" => "8",
      "certUrl" => "https://example.test/credential/abc",
      "certId" => "abc",
      "organizationName" => "A Window Between Worlds"
    )
  end

  it "prefers organizationId over organizationName when one is provided" do
    params = params_from(described_class.new(**base_args, organization_id: "1337").to_s)

    expect(params).to include("organizationId" => "1337")
    expect(params).not_to have_key("organizationName")
  end

  it "omits the issue date when there is no completion date" do
    params = params_from(described_class.new(**base_args, issued_on: nil).to_s)

    expect(params).not_to have_key("issueYear")
    expect(params).not_to have_key("issueMonth")
  end
end
