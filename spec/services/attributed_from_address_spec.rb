require "rails_helper"

RSpec.describe AttributedFromAddress do
  let(:generic) { "programs@awbw.org" }

  describe ".call" do
    it "keeps the generic address and only sets the display name" do
      sender = build_stubbed(:user, first_name: "Dana", last_name: "Sender", person: nil)

      result = described_class.call(sender, generic)

      expect(result).to eq("Dana Sender <programs@awbw.org>")
      expect(Mail::Address.new(result).address).to eq(generic)
    end

    it "returns the address untouched for automated mail with no sender" do
      expect(described_class.call(nil, generic)).to eq(generic)
    end

    it "replaces a display name the address already carried" do
      sender = build_stubbed(:user, first_name: "Dana", last_name: "Sender", person: nil)

      result = described_class.call(sender, "AWBW Portal <programs@awbw.org>")

      expect(Mail::Address.new(result).display_name).to eq("Dana Sender")
      expect(Mail::Address.new(result).address).to eq(generic)
    end

    it "quotes a name containing address special characters" do
      sender = build_stubbed(:user, first_name: "Dana,", last_name: "Sender <x@evil.test>", person: nil)

      result = described_class.call(sender, generic)

      expect(Mail::Address.new(result).address).to eq(generic)
    end

    it "strips control characters so a name cannot inject a header" do
      sender = build_stubbed(:user, first_name: "Dana\r\nBcc: x@evil.test", last_name: "Sender", person: nil)

      result = described_class.call(sender, generic)

      expect(result).not_to include("\r", "\n")
      expect(Mail::Address.new(result).address).to eq(generic)
    end

    it "falls back to the address when the sender has no usable name" do
      sender = build_stubbed(:user, first_name: " ", last_name: " ", email: "", person: nil)

      expect(described_class.call(sender, generic)).to eq(generic)
    end

    it "returns a blank address unchanged rather than building a nameless header" do
      expect(described_class.call(nil, nil)).to be_nil
    end
  end
end
