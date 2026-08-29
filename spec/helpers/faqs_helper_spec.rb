require "rails_helper"

RSpec.describe FaqsHelper, type: :helper do
  describe "#faq_admin_mode?" do
    it "is true when a manager passes ?admin" do
      allow(helper).to receive(:allowed_to?).with(:manage?, Faq).and_return(true)
      allow(helper).to receive(:params).and_return(ActionController::Parameters.new(admin: "1"))
      expect(helper.faq_admin_mode?).to be true
    end

    it "is false for a manager without the admin param" do
      allow(helper).to receive(:allowed_to?).with(:manage?, Faq).and_return(true)
      allow(helper).to receive(:params).and_return(ActionController::Parameters.new)
      expect(helper.faq_admin_mode?).to be_falsey
    end

    it "is false for a non-manager even with the admin param" do
      allow(helper).to receive(:allowed_to?).with(:manage?, Faq).and_return(false)
      allow(helper).to receive(:params).and_return(ActionController::Parameters.new(admin: "1"))
      expect(helper.faq_admin_mode?).to be_falsey
    end
  end
end
