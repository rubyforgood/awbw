require "rails_helper"

RSpec.describe FormSubmissionSittings do
  let(:start) { Time.zone.local(2026, 10, 1, 9) }

  def entry(id, role, created_at)
    FormSubmissionSittings::Entry.new(id:, form_name: "#{role} form", role:, created_at:)
  end

  it "bundles a registration with the scholarship and CE forms saved alongside it" do
    registration = entry(1, "registration", start)
    scholarship = entry(2, "scholarship", start + 1.second)
    ce = entry(3, "continuing_education", start + 2.seconds)

    sittings = described_class.new([ ce, scholarship, registration ])

    expect(sittings.groups).to eq([ [ registration, scholarship, ce ] ])
    expect(sittings.count).to eq(1)
  end

  it "joins each double-submitted application's forms to the registration saved just before them" do
    first = entry(1, "registration", start)
    first_ce = entry(2, "continuing_education", start + 0.15)
    second = entry(3, "registration", start + 0.2)
    second_ce = entry(4, "continuing_education", start + 0.3)

    expect(described_class.new([ second_ce, second, first_ce, first ]).groups).to eq([ [ first, first_ce ], [ second, second_ce ] ])
  end

  it "keeps every registration its own sitting, even seconds apart" do
    first = entry(1, "registration", start)
    second = entry(2, "registration", start + 5.seconds)
    scholarship = entry(3, "scholarship", start + 6.seconds)

    expect(described_class.new([ first, second, scholarship ]).groups).to eq([ [ first ], [ second, scholarship ] ])
  end

  it "makes a later standalone submission its own sitting, clustering forms sent together" do
    registration = entry(1, "registration", start)
    ce_alone = entry(2, "continuing_education", start + 2.days)
    scholarship = entry(3, "scholarship", start + 5.days)
    ce = entry(4, "continuing_education", start + 5.days + 1.second)

    expect(described_class.new([ ce, scholarship, ce_alone, registration ]).groups)
      .to eq([ [ registration ], [ ce_alone ], [ scholarship, ce ] ])
  end

  it "has no sittings with no submissions" do
    expect(described_class.new([]).count).to eq(0)
  end

  it "knows whether a registration is among the submissions" do
    expect(described_class.new([ entry(1, "scholarship", start) ])).not_to be_registered
    expect(described_class.new([ entry(1, "registration", start) ])).to be_registered
  end

  describe ".for_events" do
    let(:event) { create(:event) }
    let(:person) { create(:person) }
    let(:reg_form) { create(:form, name: "Reg form") }
    let(:scholarship_form) { create(:form, name: "Scholarship form") }

    before do
      create(:event_form, :registration, event: event, form: reg_form)
      create(:event_form, :scholarship, event: event, form: scholarship_form)
    end

    it "bundles by the event's form roles, even for submissions saved without a role" do
      registration = create(:form_submission, person: person, event: event, form: reg_form, role: nil, created_at: start)
      scholarship = create(:form_submission, person: person, event: event, form: scholarship_form, role: nil, created_at: start + 1.second)

      sittings = described_class.for_events(event.id, person.id)[[ person.id, event.id ]]

      expect(sittings.groups.map { |group| group.map(&:id) }).to eq([ [ registration.id, scholarship.id ] ])
      expect(sittings.groups.first.map(&:form_name)).to eq([ "Reg form", "Scholarship form" ])
      expect(sittings).to be_registered
    end

    it "leaves out bulk payments, which pay for other people" do
      create(:form_submission, person: person, event: event, form: reg_form, created_at: start)
      bulk_form = create(:form)
      create(:event_form, event: event, form: bulk_form, role: "bulk_payment")
      create(:form_submission, person: person, event: event, form: bulk_form, role: "bulk_payment", created_at: start + 3.days)

      expect(described_class.for_events(event.id, person.id)[[ person.id, event.id ]].count).to eq(1)
    end

    it "ignores forms the event doesn't link, like callout surveys" do
      create(:form_submission, person: person, event: event, form: reg_form, created_at: start)
      create(:form_submission, person: person, event: event, form: create(:form), role: "day_1_survey", created_at: start + 3.days)

      expect(described_class.for_events(event.id, person.id)[[ person.id, event.id ]].count).to eq(1)
    end
  end
end
