require "rails_helper"

RSpec.describe NotificationMailer, "#callout_form_submitted_fyi" do
  before { stub_email_config }

  it "notifies staff with the form name, registrant, and answers" do
    person = create(:person, first_name: "Ada", last_name: "Lovelace")
    event = create(:event, title: "Spring Training")
    form = create(:form, name: "Day 1 Survey")
    submission = create(:form_submission, person: person, form: form, event: event, role: "day_1_survey")
    field = create(:form_field, form: form, name: "What stood out?")
    create(:form_answer, form_submission: submission, form_field: field,
      submitted_answer: "The breakout rooms", question_name_when_answered: "What stood out?")

    mail = described_class.callout_form_submitted_fyi(submission)

    expect(mail.to).to eq([ EmailConfigHelpers::PROGRAMS_EMAIL ])
    expect(mail.subject).to include("New").and include("Day 1 Survey").and include("Ada Lovelace")
    expect(mail.body.encoded).to include("What stood out?").and include("The breakout rooms")
  end

  it "shows sector and age-group names instead of the stored ids" do
    form = create(:form, name: "Collaboration")
    submission = create(:form_submission, form: form, role: "day_1_survey")
    sector = create(:sector, name: "Domestic violence")
    age_group = create(:category, :category_age_range, name: "Ages 3-5")
    sector_field = create(:form_field, form: form, name: "Primary sector", field_identifier: "primary_sector")
    age_field = create(:form_field, form: form, name: "Primary age", field_identifier: "primary_age_group")
    create(:form_answer, form_submission: submission, form_field: sector_field,
      submitted_answer: sector.id.to_s, question_name_when_answered: "Primary sector")
    create(:form_answer, form_submission: submission, form_field: age_field,
      submitted_answer: age_group.id.to_s, question_name_when_answered: "Primary age")

    body = described_class.callout_form_submitted_fyi(submission).body.encoded

    expect(body).to include("Domestic violence").and include("Ages 3-5")
    expect(body).not_to match(/>\s*#{sector.id}\s*</)
  end

  it "says Updated in the subject and body for an edit" do
    submission = create(:form_submission, form: create(:form, name: "Day 1 Survey"))

    mail = described_class.callout_form_submitted_fyi(submission, updated: true)

    expect(mail.subject).to include("Updated Day 1 Survey submission")
    expect(mail.subject).not_to include("New Day 1 Survey")
    expect(mail.body.encoded).to include("Updated Day 1 Survey submission")
  end
end
