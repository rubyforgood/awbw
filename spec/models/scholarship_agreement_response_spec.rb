require "rails_helper"

RSpec.describe ScholarshipAgreementResponse, type: :model do
  it "belongs to a scholarship" do
    expect(described_class.new).to respond_to(:scholarship)
  end

  it "validates status is one of the known values" do
    response = build(:scholarship_agreement_response, status: "nope")
    expect(response).not_to be_valid
    expect(response.errors[:status]).to be_present
  end

  it "allows a nil responder but rejects an unknown one" do
    expect(build(:scholarship_agreement_response, responder: nil)).to be_valid
    expect(build(:scholarship_agreement_response, responder: "stranger")).not_to be_valid
  end

  it "requires responded_at" do
    expect(build(:scholarship_agreement_response, responded_at: nil)).not_to be_valid
  end

  it ".chronological orders by responded_at" do
    scholarship = create(:scholarship)
    later = create(:scholarship_agreement_response, scholarship:, responded_at: 1.hour.ago)
    earlier = create(:scholarship_agreement_response, scholarship:, responded_at: 2.hours.ago)

    expect(scholarship.agreement_responses.chronological).to eq([ earlier, later ])
  end
end
