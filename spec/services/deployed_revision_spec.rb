require "rails_helper"

RSpec.describe DeployedRevision do
  let(:sha) { "a1b2c3d4e5f60718293a4b5c6d7e8f9012345678" }

  describe ".current" do
    it "reads the deployed commit from GIT_SHA" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GIT_SHA").and_return(sha)

      expect(described_class.current.short_sha).to eq("a1b2c3d")
    end

    it "is nil when GIT_SHA is unset" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GIT_SHA").and_return("")

      expect(described_class.current).to be_nil
    end
  end

  describe "#compare_url" do
    it "compares the deployed commit to main on GitHub" do
      expect(described_class.new(sha).compare_url)
        .to eq("https://github.com/rubyforgood/awbw/compare/#{sha}...main")
    end
  end
end
