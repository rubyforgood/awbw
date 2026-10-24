require "rails_helper"

RSpec.describe FeedRecordPreloader do
  it "loads the person and event behind each comment's record" do
    registration = create(:event_registration)
    scholarship = create(:scholarship, recipient: registration.registrant)
    create(:allocation, source: scholarship, allocatable: registration, amount: 0)
    ce = create(:continuing_education_registration, event_registration: registration)
    [ registration, scholarship, ce ].each { |record| create(:comment, commentable: record) }

    comments = described_class.new(Comment.includes(:commentable).to_a).call
    loaded = comments.to_h { |comment| [ comment.commentable.class, comment.commentable ] }

    expect(loaded[EventRegistration].association(:registrant)).to be_loaded
    expect(loaded[EventRegistration].registrant.association(:user)).to be_loaded
    expect(loaded[EventRegistration].association(:event)).to be_loaded
    expect(loaded[Scholarship].association(:recipient)).to be_loaded
    expect(loaded[Scholarship].allocation.allocatable.association(:event)).to be_loaded
    expect(loaded[ContinuingEducationRegistration].event_registration.association(:registrant)).to be_loaded
  end

  it "loads a communication's noticeable person's account" do
    person = create(:person)
    notification = create(:notification, noticeable: person, recipient_email: "someone@example.com", email_subject: "Hello",
                                         kind: "manual_log", channel: "email", recipient_role: "person", notification_type: 0)

    described_class.new([ Notification.find(notification.id) ]).call.each do |entry|
      expect(entry.noticeable.association(:user)).to be_loaded
    end
  end

  it "takes the records themselves, as the picker passes them" do
    scholarship = create(:scholarship)

    records = described_class.new([ Scholarship.find(scholarship.id) ]).call

    expect(records.first.association(:allocation)).to be_loaded
  end
end
