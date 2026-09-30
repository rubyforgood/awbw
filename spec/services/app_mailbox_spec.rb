require "rails_helper"

RSpec.describe AppMailbox do
  describe ".info" do
    it "reads INFO_EMAIL" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("INFO_EMAIL").and_return("hello@example.test")

      expect(described_class.info).to eq("hello@example.test")
    end

    it "falls back to REPLY_TO_EMAIL when INFO_EMAIL is unset" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("INFO_EMAIL").and_return(nil)
      allow(ENV).to receive(:[]).with("REPLY_TO_EMAIL").and_return("replies@example.test")

      expect(described_class.info).to eq("replies@example.test")
    end

    it "is nil when nothing is configured" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("INFO_EMAIL").and_return(nil)
      allow(ENV).to receive(:[]).with("REPLY_TO_EMAIL").and_return(nil)

      expect(described_class.info).to be_nil
    end
  end
end
