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

    it "routes an Affiliation to its person and organization" do
      affiliation = create(:affiliation)

      expect(described_class.targets_for(affiliation)).to contain_exactly(
        affiliation.person,
        affiliation.organization
      )
    end

    it "routes a Comment on a Person to the person" do
      person = create(:person)
      comment = build(:comment, commentable: person)

      expect(described_class.targets_for(comment)).to eq([ person ])
    end

    it "routes a Comment on a User to their person" do
      person = create(:person)
      user = create(:user, person: person)
      comment = build(:comment, commentable: user)

      expect(described_class.targets_for(comment)).to eq([ person ])
    end

    it "routes a Comment on an EventRegistration to the registration and registrant" do
      registration = create(:event_registration)
      comment = build(:comment, commentable: registration)

      expect(described_class.targets_for(comment)).to contain_exactly(
        registration,
        registration.registrant
      )
    end

    it "routes a Comment on a ContinuingEducationRegistration to its registrant" do
      ce_reg = create(:continuing_education_registration)
      comment = build(:comment, commentable: ce_reg)

      expect(described_class.targets_for(comment)).to contain_exactly(ce_reg.registrant)
    end

    it "routes a Comment on a Scholarship to its recipient" do
      scholarship = create(:scholarship)
      comment = build(:comment, commentable: scholarship)

      expect(described_class.targets_for(comment)).to contain_exactly(scholarship.recipient)
    end

    it "routes a Comment on a TopicSubscription to the subscriber" do
      topic_subscription = create(:topic_subscription)
      comment = build(:comment, commentable: topic_subscription)

      expect(described_class.targets_for(comment)).to contain_exactly(topic_subscription.person)
    end

    it "routes a Comment on an Organization to the organization" do
      organization = create(:organization)
      comment = build(:comment, commentable: organization)

      expect(described_class.targets_for(comment)).to eq([ organization ])
    end
  end
end
