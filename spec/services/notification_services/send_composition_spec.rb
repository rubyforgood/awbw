require "rails_helper"

RSpec.describe NotificationServices::SendComposition do
  let(:owner) { create(:user, email: "admin@example.org") }
  let(:composition) do
    create(:notification_composition, user: owner, subject: "Spring news", body: "Hello there")
  end
  let(:recipients) { create_list(:person, 3) }

  it "creates one FYI parent plus one child per recipient" do
    fyi = described_class.call(composition, recipients: recipients)

    expect(fyi.kind).to eq("bulk_email_fyi")
    expect(fyi.recipient_role).to eq("admin")
    expect(fyi.recipient_email).to eq("admin@example.org")

    children = Notification.where(batch_root_notification_id: fyi.id)
    expect(children.count).to eq(3)
    expect(children.pluck(:kind).uniq).to eq([ "bulk_email" ])
    expect(children.pluck(:person_id)).to match_array(recipients.map(&:id))
  end

  it "copies the composed subject and body onto the FYI and every child" do
    fyi = described_class.call(composition, recipients: recipients)
    batch = Notification.where(batch_root_notification_id: fyi.id).to_a + [ fyi ]

    expect(batch.map(&:custom_subject).uniq).to eq([ "Spring news" ])
    expect(batch.map(&:custom_message).uniq).to eq([ "Hello there" ])
  end

  it "skips recipients without an email" do
    no_email = create(:person)
    allow(no_email).to receive(:preferred_email).and_return(nil)

    fyi = described_class.call(composition, recipients: recipients + [ no_email ])
    expect(Notification.where(batch_root_notification_id: fyi.id).count).to eq(3)
  end
end
