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

  describe "agreement status pill" do
    it "labels and colours each of the three states" do
      scholarship = create(:scholarship, recipient: recipient)
      expect(scholarship.decorate).to have_attributes(agreement_status_label: "Pending", agreement_status_classes: a_string_including("amber"))

      scholarship.update!(agreement_signed: true)
      expect(scholarship.decorate).to have_attributes(agreement_status_label: "Signed", agreement_status_classes: a_string_including("fuchsia"))

      scholarship.decline_agreement!("Timing no longer works")
      expect(scholarship.decorate).to have_attributes(agreement_status_label: "Declined", agreement_status_classes: a_string_including("red"))

      scholarship.request_additional_support!(contribution_cents: 5_000)
      expect(scholarship.decorate).to have_attributes(agreement_status_label: "Support requested", agreement_status_classes: a_string_including("sky"))
    end

    it "renders the badge only for a declined award by default" do
      scholarship = create(:scholarship, recipient: recipient)
      expect(scholarship.decorate.agreement_status_badge).to be_nil

      scholarship.decline_agreement!("Timing no longer works")
      expect(scholarship.decorate.agreement_status_badge).to include("Declined", "fa-circle-xmark")
    end

    it "renders the badge for a support-requested award by default (needs follow-up)" do
      scholarship = create(:scholarship, recipient: recipient)
      scholarship.request_additional_support!(contribution_cents: 5_000)

      expect(scholarship.decorate.agreement_status_badge).to include("Support requested")
    end

    it "renders every state, prefixed, when asked" do
      scholarship = create(:scholarship, recipient: recipient)

      expect(scholarship.decorate.agreement_status_badge(all_states: true, prefix: true)).to include("Agreement pending")
    end
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

  describe "program status, anchored on the training the award paid for" do
    let(:org) { create(:organization, name: "Prevail") }

    def award_at(training, recipient_person = recipient)
      registration = create(:event_registration, event: training, registrant: recipient_person)
      scholarship = create(:scholarship, recipient: recipient_person)
      create(:allocation, source: scholarship, allocatable: registration, amount: 0)
      scholarship.reload.decorate
    end

    it "is Ongoing when the program was already facilitating at that training" do
      training = create(:event, facilitator_training: true, start_date: Date.new(2025, 6, 1))
      create(:affiliation, person: recipient, organization: org, title: "Facilitator", start_date: Date.new(2020, 1, 1))

      expect(award_at(training).program_status).to eq("Ongoing")
    end

    it "is New when the only facilitator affiliation starts after that training" do
      training = create(:event, facilitator_training: true, start_date: Date.new(2025, 6, 1))
      create(:affiliation, person: recipient, organization: org, title: "Facilitator", start_date: Date.new(2025, 9, 1))

      expect(award_at(training).program_status).to eq("New")
    end

    it "is Reinstated when the program had lapsed by that training" do
      training = create(:event, facilitator_training: true, start_date: Date.new(2025, 6, 1))
      create(:affiliation, person: create(:person), organization: org, title: "Facilitator",
                           start_date: Date.new(2015, 1, 1), end_date: Date.new(2018, 1, 1))
      create(:affiliation, person: recipient, organization: org, title: "Facilitator", start_date: Date.new(2025, 6, 1))

      expect(award_at(training).program_status).to eq("Reinstated")
    end

    it "judges two awards at their own trainings, not at one page-wide date" do
      create(:affiliation, person: recipient, organization: org, title: "Facilitator", start_date: Date.new(2020, 3, 1))
      early = create(:event, facilitator_training: true, start_date: Date.new(2018, 6, 1))
      late = create(:event, facilitator_training: true, start_date: Date.new(2024, 6, 1))

      expect(award_at(early).program_status).to eq("New")
      expect(award_at(late).program_status).to eq("Ongoing")
    end

    it "falls back to the year anchor when no registration backs the award" do
      create(:affiliation, person: recipient, organization: org, title: "Facilitator", start_date: Date.new(2020, 3, 1))
      scholarship = create(:scholarship, recipient: recipient).decorate

      expect(scholarship.program_status).to eq("Ongoing")
      expect(scholarship.program_status_explanation).to include("no event in view")
    end

    it "explains the verdict against the training's own start date" do
      training = create(:event, facilitator_training: true, start_date: Date.new(2025, 6, 1))
      create(:affiliation, person: recipient, organization: org, title: "Facilitator", start_date: Date.new(2020, 1, 1))

      expect(award_at(training).program_status_explanation).to include("Jun 1, 2025", "event start date")
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
