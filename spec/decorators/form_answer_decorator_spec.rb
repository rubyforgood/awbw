require "rails_helper"

RSpec.describe FormAnswerDecorator do
  describe "#tooltip_text" do
    it "returns plain text unchanged" do
      answer = build(:form_answer, submitted_answer: "Just a plain answer")
      expect(answer.decorate.tooltip_text).to eq("Just a plain answer")
    end

    it "pretty-prints a JSON object" do
      answer = build(:form_answer, submitted_answer: '{"role":"admin","active":true}')
      expect(answer.decorate.tooltip_text).to eq(<<~JSON.strip)
        {
          "role": "admin",
          "active": true
        }
      JSON
    end

    it "leaves malformed JSON as-is" do
      answer = build(:form_answer, submitted_answer: "{not really json")
      expect(answer.decorate.tooltip_text).to eq("{not really json")
    end
  end
end
