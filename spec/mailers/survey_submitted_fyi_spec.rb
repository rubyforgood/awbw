require "rails_helper"

RSpec.describe NotificationMailer, "#survey_submitted_fyi" do
  it "notifies staff with the form name, registrant, and answers" do
    person = create(:person, first_name: "Ada", last_name: "Lovelace")
    event = create(:event, title: "Spring Training")
    form = create(:form, name: "Day 1 Survey")
    submission = create(:form_submission, person: person, form: form, event: event, role: "day_1_survey")
    field = create(:form_field, form: form, name: "What stood out?")
    create(:form_answer, form_submission: submission, form_field: field,
      submitted_answer: "The breakout rooms", question_name_when_answered: "What stood out?")

    mail = described_class.survey_submitted_fyi(submission)

    expect(mail.to).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
    expect(mail.subject).to include("Day 1 Survey").and include("Ada Lovelace")
    expect(mail.body.encoded).to include("What stood out?").and include("The breakout rooms")
  end
end
