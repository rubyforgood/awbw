require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#staging_environment?" do
    context "when RAILS_ENV is staging" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("staging")
      end

      it "returns true" do
        expect(helper.staging_environment?).to be true
      end
    end

    context "when Rails.env is staging" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RAILS_ENV").and_return(nil)
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("staging"))
      end

      it "returns true" do
        expect(helper.staging_environment?).to be true
      end
    end

    context "when environment is not staging" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("production")
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      end

      it "returns false" do
        expect(helper.staging_environment?).to be false
      end
    end
  end

  describe "#navbar_bg_class" do
    context "when in staging environment" do
      before do
        allow(helper).to receive(:staging_environment?).and_return(true)
      end

      it "returns bg-red-600" do
        expect(helper.navbar_bg_class).to eq("bg-red-600")
      end
    end

    context "when not in staging environment" do
      before do
        allow(helper).to receive(:staging_environment?).and_return(false)
      end

      it "returns bg-primary" do
        expect(helper.navbar_bg_class).to eq("bg-primary")
      end
    end
  end
end
