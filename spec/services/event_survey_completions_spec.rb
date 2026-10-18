require "rails_helper"

RSpec.describe EventSurveyCompletions do
  let(:event) { create(:event) }
  let(:person) { create(:person) }
  let(:day_1) { create(:form, role: "day_1_survey") }
  let(:day_2) { create(:form, role: "day_2_survey") }
  let(:post_event) { create(:form, role: "post_event_survey") }

  def completions = described_class.new(event, [ person.id ])

  describe "#roles" do
    it "lists survey roles delivered on any callout, hidden ones included, in role order" do
      create(:registration_ticket_callout, :hidden, event:, forms: [ post_event, day_1 ])
      create(:registration_ticket_callout, event:, form: create(:form, role: "general"))

      expect(completions.roles).to eq(%w[day_1_survey post_event_survey])
    end

    it "includes a survey answered for the event even when no callout delivers it" do
      create(:form_submission, form: day_2, event:, person:)

      expect(completions.roles).to eq(%w[day_2_survey])
    end

    it "ignores another event's callouts and submissions" do
      other = create(:event)
      create(:registration_ticket_callout, event: other, form: day_1)
      create(:form_submission, form: day_2, event: other, person:)

      expect(completions.roles).to be_empty
    end
  end

  describe "#completion" do
    it "returns the registrant's first submission of the role" do
      first = create(:form_submission, form: day_1, event:, person:, created_at: 2.days.ago)
      create(:form_submission, form: day_1, event:, person:, created_at: 1.day.ago)

      completion = completions.completion(person.id, "day_1_survey")

      expect(completion.submission_id).to eq(first.id)
      expect(completion.submitted_at).to be_within(1.second).of(first.created_at)
    end

    it "matches on the form's current role" do
      general = create(:form, role: "general")
      create(:form_submission, form: general, event:, person:, role: "general")
      general.update!(role: "day_2_survey")

      expect(completions.completion(person.id, "day_2_survey")).to be_present
    end

    it "is nil when the registrant hasn't submitted the role" do
      create(:registration_ticket_callout, event:, form: day_1)

      expect(completions.completion(person.id, "day_1_survey")).to be_nil
    end
  end
end
