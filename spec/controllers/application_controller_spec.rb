require "rails_helper"

RSpec.describe ApplicationController do
  # Autosave copies a nested record's errors onto its parent keyed
  # "<association>.<attribute>", where the default full message pastes the humanized
  # association name in front. The flash has to read as the child model wrote it.
  describe "#error_sentence" do
    subject(:sentence) do
      registration.valid?
      described_class.new.send(:error_sentence, registration)
    end

    let(:registration) { create(:event_registration) }

    before { registration.event_attendance_time_entries.build(entry_attributes) }

    context "with a child error written as a whole sentence" do
      let(:entry_attributes) { { signed_in_at: Time.current, signed_out_at: 1.hour.ago } }

      it "reads verbatim" do
        expect(sentence).to eq("Sign-out must be after the sign-in time.")
      end
    end

    context "with a child error on one attribute" do
      let(:entry_attributes) { { signed_in_at: nil } }

      it "keeps the child's own subject rather than dropping to a bare fragment" do
        expect(sentence).to eq("Signed in at can't be blank")
      end
    end
  end
end
