require "rails_helper"

RSpec.describe FormsHelper, type: :helper do
  describe "#max_length_placeholder" do
    it "names the input and its limit" do
      expect(helper.max_length_placeholder("Question text", 1000)).to eq("Question text (1,000 char max)")
    end
  end
end
