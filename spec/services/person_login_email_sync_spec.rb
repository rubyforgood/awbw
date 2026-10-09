require "rails_helper"

RSpec.describe PersonLoginEmailSync do
  let(:person) { create(:person, user: nil, first_name: "Jamie", last_name: "Rivera", email: "work@example.com", email_type: "work") }
  let(:user) { create(:user, email: "login@example.com", email_type: "personal") }

  def link
    user.update_column(:person_id, person.id)
    user.reload
  end

  it "makes the login email the primary email and moves the old one to the secondary slot" do
    link

    expect(described_class.call(user)).to be(true)
    expect(person.reload).to have_attributes(
      email: "login@example.com", email_type: "personal",
      email_2: "work@example.com", email_2_type: "work"
    )
  end

  it "swaps the two addresses when the secondary email is already the login email" do
    person.update!(email_2: "LOGIN@example.com", email_2_type: "personal")
    link

    described_class.call(user)

    expect(person.reload).to have_attributes(
      email: "login@example.com", email_type: "personal",
      email_2: "work@example.com", email_2_type: "work"
    )
  end

  it "keeps the replaced address in an admin comment when the secondary slot holds another address" do
    person.update!(email_2: "other@example.com")
    link

    described_class.call(user)

    expect(person.reload).to have_attributes(email: "login@example.com", email_2: "other@example.com")
    expect(person.comments.sole.body).to include("work@example.com")
  end

  it "fills a blank primary email without touching the secondary one" do
    person.update!(email: nil, email_2: "other@example.com")
    link

    described_class.call(user)

    expect(person.reload).to have_attributes(email: "login@example.com", email_2: "other@example.com")
    expect(person.comments).to be_empty
  end

  it "leaves the person alone when the emails already match ignoring case" do
    person.update!(email: "Login@Example.com")
    link

    expect { described_class.call(user) }.not_to change { person.reload.updated_at }
  end

  it "is a no-op for a user without a person" do
    expect(described_class.call(user)).to be(true)
  end

  it "reports the failure and leaves the person unchanged when the login email would duplicate another person" do
    create(:person, user: nil, first_name: "Jamie", last_name: "Rivera", email: "login@example.com")
    link
    allow(Rails.error).to receive(:report)

    expect(described_class.call(user)).to be(false)
    expect(Rails.error).to have_received(:report).with(an_instance_of(ActiveRecord::RecordInvalid), hash_including(handled: true))
    expect(person.reload.email).to eq("work@example.com")
    expect(user.person).not_to be_changed
  end
end
