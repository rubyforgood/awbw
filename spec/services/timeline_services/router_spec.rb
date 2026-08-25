# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimelineServices::Router do
  let(:holder_class) do
    stub_const("SpecTimelineHolder", Class.new(ApplicationRecord) do
      self.table_name = "people"
      include HasTimeline
    end)
  end

  describe ".targets_for" do
    it "routes a record with a timeline to itself" do
      holder = holder_class.find(create(:person).id)

      expect(described_class.targets_for(holder)).to eq([ holder ])
    end

    it "routes records without timelines nowhere" do
      plain_class = stub_const("SpecPlainRecord", Class.new(ApplicationRecord) do
        self.table_name = "people"
      end)
      plain_record = plain_class.find(create(:person).id)

      expect(described_class.targets_for(plain_record)).to eq([])
    end

    it "routes a Notification to its noticeable record" do
      person = create(:person)
      notification = build(:notification, noticeable: person)

      expect(described_class.targets_for(notification)).to eq([ person ])
    end

    it "routes a Notification with nil noticeable nowhere" do
      notification = build(:notification, noticeable: nil)

      expect(described_class.targets_for(notification)).to eq([])
    end

    it "routes a Scholarship to its recipient" do
      scholarship = build(:scholarship)

      expect(described_class.targets_for(scholarship)).to eq([ scholarship.recipient ])
    end

    it "routes a ContinuingEducationRegistration to its registrant and registration" do
      ce_reg = create(:continuing_education_registration)

      expect(described_class.targets_for(ce_reg)).to contain_exactly(
        ce_reg.event_registration.registrant,
        ce_reg.event_registration
      )
    end

    it "routes a FormSubmission to its person" do
      submission = create(:form_submission)

      expect(described_class.targets_for(submission)).to eq([ submission.person ])
    end

    it "routes an event-linked FormSubmission to its person and matching registration" do
      event = create(:event)
      person = create(:person)
      registration = create(:event_registration, event: event, registrant: person)
      submission = create(:form_submission, :with_event, person: person, event: event)

      expect(described_class.targets_for(submission)).to contain_exactly(person, registration)
    end

    it "routes an event-linked FormSubmission to person only when no matching registration exists" do
      event = create(:event)
      person = create(:person)
      submission = create(:form_submission, :with_event, person: person, event: event)

      expect(described_class.targets_for(submission)).to eq([ person ])
    end

    it "routes an Affiliation to its person" do
      affiliation = create(:affiliation)

      expect(described_class.targets_for(affiliation)).to eq([ affiliation.person ])
    end
  end
end
