require "rails_helper"

RSpec.describe StripeMetadata do
  subject(:metadata) { host.send(:stripe_metadata, attributes) }

  let(:host) { Class.new { include StripeMetadata }.new }

  context "with values within Stripe's limit" do
    let(:attributes) { { form_submission_id: 12, event_id: 3 } }

    it "passes them through, preserving their type" do
      expect(metadata).to eq(form_submission_id: 12, event_id: 3)
    end
  end

  context "with a value longer than Stripe's 500-character cap" do
    let(:attributes) { { note: "a" * 972, event_id: 3 } }

    it "truncates the value to the cap" do
      expect(metadata[:note].length).to eq(described_class::STRIPE_METADATA_VALUE_LIMIT)
      expect(metadata[:note]).to eq("#{"a" * 497}...")
    end

    it "leaves the other values untouched" do
      expect(metadata[:event_id]).to eq(3)
    end
  end
end
