require "rails_helper"

RSpec.describe AffiliationServices::CloseProgram do
  let(:person) { create(:person, user: nil) }
  let(:organization) { create(:organization, name: "Sunset Youth Services") }
  let(:other_org) { create(:organization, name: "Harbor Family Shelter") }
  let(:effective_date) { Date.new(2026, 6, 30) }

  def call_with(leaving_job:, reason: "Grant funding ended.")
    described_class.call(person: person, organization: organization,
                         effective_date: effective_date, reason: reason, leaving_job: leaving_job)
  end

  it "end-dates the facilitator affiliation to the effective date and comments why" do
    facilitator = create(:affiliation, person: person, organization: organization, title: "Facilitator")

    ended = call_with(leaving_job: false)

    expect(facilitator.reload.end_date).to eq(effective_date)
    expect(ended).to contain_exactly(facilitator)
    comment = facilitator.comments.last
    expect(comment.topic).to eq("Program closure")
    expect(comment.body).to include("Grant funding ended.")
    expect(comment.body).to include(effective_date.to_fs(:long))
  end

  it "leaves the job affiliation alone when they aren't leaving the job" do
    facilitator = create(:affiliation, person: person, organization: organization, title: "Facilitator")
    job = create(:affiliation, person: person, organization: organization, title: "Program Director")

    ended = call_with(leaving_job: false)

    expect(job.reload.end_date).to be_nil
    expect(ended).to contain_exactly(facilitator)
  end

  it "also end-dates the job affiliation when they are leaving the job" do
    facilitator = create(:affiliation, person: person, organization: organization, title: "Facilitator")
    job = create(:affiliation, person: person, organization: organization, title: "Program Director")

    ended = call_with(leaving_job: true)

    expect(job.reload.end_date).to eq(effective_date)
    expect(ended).to contain_exactly(facilitator, job)
    expect(job.comments.last.topic).to eq("Program closure")
  end

  it "only touches affiliations at the named organization" do
    elsewhere = create(:affiliation, person: person, organization: other_org, title: "Facilitator")

    call_with(leaving_job: true)

    expect(elsewhere.reload.end_date).to be_nil
  end

  it "leaves an already-ended row untouched" do
    long_gone = create(:affiliation, person: person, organization: organization, title: "Facilitator",
                       end_date: Date.new(2024, 1, 31))

    ended = call_with(leaving_job: false)

    expect(long_gone.reload.end_date).to eq(Date.new(2024, 1, 31))
    expect(ended).to be_empty
  end

  it "records a date-only comment when no reason was given" do
    facilitator = create(:affiliation, person: person, organization: organization, title: "Facilitator")

    call_with(leaving_job: false, reason: nil)

    expect(facilitator.comments.last.body).to eq("Program closed effective #{effective_date.to_fs(:long)}.")
  end
end
