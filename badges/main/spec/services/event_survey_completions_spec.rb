require "rails_helper"

RSpec.describe EventSurveyCompletions do
  let(:event) { create(:event, facilitator_training: true, cost_cents: 1099) }
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

    context "which surveys each kind of event offers" do
      let(:recipient) { create(:form, role: "recipient_survey") }

      before do
        create(:registration_ticket_callout, :hidden, event:, forms: [ day_1, day_2, post_event ])
        create(:registration_ticket_callout, :hidden, event:, form: recipient)
      end

      it "offers all four on a paid, multi-day live facilitator training" do
        expect(completions.roles).to eq(%w[day_1_survey day_2_survey recipient_survey post_event_survey])
      end

      it "drops Day 2 on a one-day training" do
        event.update!(end_date: event.start_date)

        expect(completions.roles).to eq(%w[day_1_survey recipient_survey post_event_survey])
      end

      it "drops Day 2 on a one-day evening training even for a viewer whose zone puts the end on the next day" do
        pacific = Time.find_zone(Event::PROGRAM_ZONE)
        event.update!(start_date: pacific.local(2026, 9, 10, 9), end_date: pacific.local(2026, 9, 10, 22))

        roles = Time.use_zone("Eastern Time (US & Canada)") { described_class.new(Event.find(event.id), [ person.id ]).roles }

        expect(roles).to eq(%w[day_1_survey recipient_survey post_event_survey])
      end

      it "drops Day 1 and Day 2 on an on-demand training" do
        event.update!(on_demand: true)

        expect(completions.roles).to eq(%w[recipient_survey post_event_survey])
      end

      it "drops Day 1 and Day 2 on an event that isn't a facilitator training" do
        event.update!(facilitator_training: false)

        expect(completions.roles).to eq(%w[recipient_survey post_event_survey])
      end

      it "drops the scholarship survey on a free event" do
        event.update!(cost_cents: 0)

        expect(completions.roles).to eq(%w[day_1_survey day_2_survey post_event_survey])
      end
    end

    it "includes a survey answered for the event even when the event doesn't offer it" do
      event.update!(facilitator_training: false)
      create(:form_submission, form: day_1, event:, person:)

      expect(completions.roles).to eq(%w[day_1_survey])
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

    context "on an anonymous survey" do
      before { day_1.update!(anonymous: true) }

      it "returns the registrant's completion date with no submission to link to" do
        create(:form_completion, form: day_1, event:, person:, completed_on: Date.new(2026, 10, 30))

        completion = completions.completion(person.id, "day_1_survey")

        expect(completion.submission_id).to be_nil
        expect(completion.submitted_at.to_date).to eq(Date.new(2026, 10, 30))
      end

      it "credits no one for an anonymous submission on its own" do
        create(:form_submission, form: day_1, event:, person: nil)

        expect(completions.completion(person.id, "day_1_survey")).to be_nil
      end

      it "counts the survey as answered for the event" do
        create(:form_completion, form: day_1, event:, person:)
        event.update!(facilitator_training: false)

        expect(completions.roles).to eq(%w[day_1_survey])
      end
    end

    it "is nil when the registrant hasn't submitted the role" do
      create(:registration_ticket_callout, event:, form: day_1)

      expect(completions.completion(person.id, "day_1_survey")).to be_nil
    end
  end
end
