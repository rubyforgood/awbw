require "rails_helper"

RSpec.describe NotificationMailer, "#callout_form_submitted_fyi" do
  it "notifies staff with the form name, registrant, and answers" do
    person = create(:person, first_name: "Ada", last_name: "Lovelace")
    event = create(:event, title: "Spring Training")
    form = create(:form, name: "Day 1 Survey")
    submission = create(:form_submission, person: person, form: form, event: event, role: "day_1_survey")
    field = create(:form_field, form: form, name: "What stood out?")
    create(:form_answer, form_submission: submission, form_field: field,
      submitted_answer: "The breakout rooms", question_name_when_answered: "What stood out?")

    mail = described_class.callout_form_submitted_fyi(submission)

    expect(mail.to).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
    expect(mail.subject).to include("New").and include("Day 1 Survey").and include("Ada Lovelace")
    expect(mail.body.encoded).to include("What stood out?").and include("The breakout rooms")
  end

  it "says Updated in the subject and body for an edit" do
    submission = create(:form_submission, form: create(:form, name: "Day 1 Survey"))

    mail = described_class.callout_form_submitted_fyi(submission, updated: true)

    expect(mail.subject).to include("Updated Day 1 Survey submission")
    expect(mail.subject).not_to include("New Day 1 Survey")
    expect(mail.body.encoded).to include("Updated Day 1 Survey submission")
  end
end
