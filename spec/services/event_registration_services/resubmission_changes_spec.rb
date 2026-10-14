require "rails_helper"

RSpec.describe EventRegistrationServices::ResubmissionChanges do
  let(:unchanged) do
    { scholarship_requested: false, ce_requested: false, w9_requested: false, invoice_requested: false,
      expected_payment_method: "Check", someone_else_will_pay: false }
  end

  describe ".snapshot" do
    it "captures the registration's resubmittable state" do
      registration = create(:event_registration, scholarship_requested: true, w9_requested: true,
                                                 expected_payment_method: "Check")

      expect(described_class.snapshot(registration)).to eq(
        scholarship_requested: true, ce_requested: false, w9_requested: true, invoice_requested: false,
        expected_payment_method: "Check", someone_else_will_pay: false
      )
    end
  end

  describe ".between" do
    it "has no notes when nothing changed" do
      expect(described_class.between(unchanged, unchanged).notes).to be_empty
    end

    it "notes every newly requested item" do
      after = unchanged.merge(scholarship_requested: true, ce_requested: true, w9_requested: true, invoice_requested: true)

      expect(described_class.between(unchanged, after).notes).to eq([
        "Scholarship now requested",
        "Continuing education credit now requested",
        "W-9 now requested",
        "Invoice now requested"
      ])
    end

    it "notes a payment method change, including one set for the first time" do
      expect(described_class.between(unchanged, unchanged.merge(expected_payment_method: "Credit card")).notes)
        .to eq([ "Payment method changed from Check to Credit card" ])
      expect(described_class.between(unchanged.merge(expected_payment_method: nil), unchanged).notes)
        .to eq([ "Payment method changed from none to Check" ])
    end

    it "notes who's paying in either direction" do
      paying = unchanged.merge(someone_else_will_pay: true)

      expect(described_class.between(unchanged, paying).notes).to eq([ "Someone else will now pay" ])
      expect(described_class.between(paying, unchanged).notes).to eq([ "Someone else is no longer paying" ])
    end
  end

  describe "#subject_suffix" do
    it "calls out a scholarship request first" do
      changes = described_class.new([ "W-9 now requested", described_class::SCHOLARSHIP_REQUESTED ])

      expect(changes.subject_suffix).to eq(" (scholarship now requested)")
    end

    it "flags any other change generically" do
      expect(described_class.new([ "W-9 now requested" ]).subject_suffix).to eq(" (registration changed)")
    end

    it "is nil with no changes" do
      expect(described_class.new([]).subject_suffix).to be_nil
    end
  end

  it "round-trips notes through the notification message" do
    changes = described_class.new([ "W-9 now requested", "Invoice now requested" ])

    expect(described_class.from_message(changes.to_message).notes).to eq(changes.notes)
    expect(described_class.new([]).to_message).to be_nil
  end
end
