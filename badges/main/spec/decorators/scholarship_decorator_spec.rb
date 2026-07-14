require "rails_helper"

RSpec.describe ScholarshipDecorator, type: :decorator do
  let(:recipient) { create(:person, first_name: "Carmen", last_name: "Gomez") }

  it "formats the amount and recipient name" do
    scholarship = create(:scholarship, recipient: recipient, amount_cents: 150_000).decorate
    expect(scholarship.amount).to eq("$1,500.00")
    expect(scholarship.recipient_name).to eq("Carmen Gomez")
  end

  it "reflects the agreement_signed flag" do
    expect(create(:scholarship, recipient: recipient, agreement_signed: false).decorate.agreement_signed?).to be(false)
    expect(create(:scholarship, recipient: recipient, agreement_signed: true).decorate.agreement_signed?).to be(true)
  end

  describe "program columns derived from the recipient's facilitator affiliation" do
    let(:org) { create(:organization, name: "Prevail") }

    before do
      create(:address, addressable: org, city: "Stockton", state: "CA")
      create(:affiliation, person: recipient, organization: org, title: "Facilitator")
    end

    it "shows the program name, location, and status" do
      scholarship = create(:scholarship, recipient: recipient).decorate

      expect(scholarship.program_name).to eq("Prevail")
      expect(scholarship.program_location).to eq("Stockton, CA")
      expect(scholarship.program_status).to eq("New")
    end
  end

  describe "training column" do
    it "lists the attended facilitator-training event" do
      training = create(:event, title: "TAC251", facilitator_training: true)
      create(:event_registration, registrant: recipient, event: training, status: "attended")
      scholarship = create(:scholarship, recipient: recipient).decorate

      expect(scholarship.training_label).to eq("TAC251")
    end

    it "falls back to a dash with no completed training" do
      scholarship = create(:scholarship, recipient: recipient).decorate
      expect(scholarship.training_label).to eq("—")
    end
  end

  it "dashes the program columns when the recipient has no facilitator affiliation" do
    scholarship = create(:scholarship, recipient: recipient).decorate
    expect(scholarship.program_name).to eq("—")
    expect(scholarship.program_location).to eq("—")
    expect(scholarship.program_status).to eq("—")
  end
end
