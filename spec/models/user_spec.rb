require "rails_helper"

RSpec.describe User do
  # Use FactoryBot
  # let(:user) { build(:user) } # Keep build for simple validation tests

  describe "associations" do
    # Need create for association tests to work correctly with callbacks
    subject { create(:user) }

    it { should belong_to(:person).optional }
    it { should have_many(:workshops) }
    it { should have_many(:workshop_logs) }
    it { should have_many(:reports) }
    # Through associations require more setup, test manually if complex
    # it { should have_many(:communal_reports).through(:organizations).source(:reports) }
    it { should have_many(:bookmarks).dependent(:destroy) }
    it { should have_many(:bookmarked_workshops).through(:bookmarks).source(:bookmarkable) }
    it { should have_many(:bookmarked_resources).through(:bookmarks).source(:bookmarkable) }
    it { should have_many(:bookmarked_events).through(:bookmarks).source(:bookmarkable) }

    it { should have_many(:windows_types).through(:organizations) }
    it { should have_many(:resources) }
    it { should have_many(:user_forms).dependent(:destroy) }
    it { should have_many(:user_form_form_fields).through(:user_forms).dependent(:destroy) }
    # Custom scope/select for colleagues might interfere
    # it { should have_many(:colleagues).through(:organizations).source(:organization_users) }
    it { should have_many(:notifications) } # As :noticeable

    # Nested Attributes
    it { should accept_nested_attributes_for(:user_forms) }
  end

  describe "strip_whitespace" do
    it "strips leading and trailing whitespace from email" do
      user = create(:user, email: "  jane@test.org  ")
      expect(user.email).to eq("jane@test.org")
    end
  end

  describe "validations" do
    # Devise validations (presence tested manually below, uniqueness tested with subject)
    subject { create(:user) } # Use create for uniqueness tests
    it { should validate_uniqueness_of(:email).case_insensitive }
    # it { should validate_length_of(:password).is_at_least(Devise.password_length.first).is_at_most(Devise.password_length.last) }

    # Manual presence tests (using build is fine here)
    let(:user) { build(:user) }
    it "is valid with valid attributes" do
      expect(user).to be_valid
    end

    it "is invalid without an email" do
      user.email = nil
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it "is invalid without a password" do
      user.password = nil
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    # Commented out validations in model
    # it { should validate_presence_of(:first_name) }
    # it { should validate_presence_of(:last_name) }
  end

  describe "bookmark_associations" do
    it { should have_many(:bookmarks) }

    it "has many bookmarked_workshops through bookmarks" do
      expect(User.reflect_on_association(:bookmarked_workshops).macro).to eq(:has_many)
      expect(User.reflect_on_association(:bookmarked_workshops).options[:through]).to eq(:bookmarks)
      expect(User.reflect_on_association(:bookmarked_workshops).options[:source]).to eq(:bookmarkable)
    end

    it "has many bookmarked_resources through bookmarks" do
      expect(User.reflect_on_association(:bookmarked_resources).macro).to eq(:has_many)
      expect(User.reflect_on_association(:bookmarked_resources).options[:through]).to eq(:bookmarks)
      expect(User.reflect_on_association(:bookmarked_resources).options[:source]).to eq(:bookmarkable)
    end
  end

  describe "polymorphic source_type filtering" do
    let(:user) { create(:user) }
    let(:workshop) { create(:workshop) }
    let(:resource) { create(:resource) }

    before do
      user.bookmarks.create(bookmarkable: workshop)
      user.bookmarks.create(bookmarkable: resource)
    end

    it "bookmarked_workshops only includes Workshop bookmarks" do
      expect(user.bookmarked_workshops).to include(workshop)
      expect(user.bookmarked_workshops).not_to include(resource)
    end

    it "bookmarked_resources only includes Resource bookmarks" do
      expect(user.bookmarked_resources).to include(resource)
      expect(user.bookmarked_resources).not_to include(workshop)
    end
  end

  describe "#full_name" do
    context "when user has a person" do
      it "returns the person's full name" do
        person = create(:person, first_name: "John", last_name: "Doe")
        expect(person.user.full_name).to eq("John Doe")
      end
    end

    context "when user has no person" do
      it "returns the email" do
        user = build(:user)
        expect(user.full_name).to eq(user.email)
      end
    end
  end

  describe '#bookmark_for' do
    let(:user) { create(:user) }
    let(:workshop) { create(:workshop) }

    it 'returns the bookmark object if it exists' do
      bookmark = create(:bookmark, user: user, bookmarkable: workshop)
      expect(user.bookmark_for(workshop)).to eq(bookmark)
    end

    it 'returns nil if bookmark does not exist' do
      expect(user.bookmark_for(workshop)).to be_nil
    end
  end

  describe "person association" do
    it "can be created without a person" do
      user = create(:user)
      expect(user.person).to be_nil
    end

    it "can be linked to a person" do
      person = create(:person)
      expect(person.user).to eq(person.user)
      expect(person.user.person).to eq(person)
    end

    it "delegates organizations through person" do
      person = create(:person, :with_organization)
      expect(person.user.organizations).to eq(person.organizations)
    end
  end

  describe "#person_id_must_be_present_if_previously_set" do
    it "prevents removing person_id once set" do
      person = create(:person)
      user = person.user
      user.person_id = nil
      expect(user).not_to be_valid
      expect(user.errors[:person_id]).to include("cannot be removed once set")
    end

    it "allows saving when person_id remains set" do
      person = create(:person)
      user = person.user
      user.email = "updated@test.org"
      expect(user).to be_valid
    end

    it "allows user without person_id to remain without one" do
      user = create(:user)
      user.email = "updated@test.org"
      expect(user).to be_valid
    end
  end

  describe "validates_associated :person" do
    it "is invalid when associated person is invalid" do
      person = create(:person)
      user = person.user
      person.first_name = nil # Person requires first_name
      expect(user).not_to be_valid
    end
  end

  describe "#name" do
    it "returns person full_name when person is present" do
      person = build(:person, first_name: "Bob", last_name: "Smith")
      user = build(:user, person: person)
      expect(user.name).to eq("Bob Smith")
    end

    it "returns email when no person" do
      user = build(:user, person: nil)
      expect(user.name).to eq(user.email)
    end
  end

  describe "#active_for_authentication?" do
    it "returns true when not inactive" do
      user = create(:user, inactive: false)
      expect(user.active_for_authentication?).to be true
    end

    it "returns false when inactive" do
      user = create(:user, inactive: true)
      expect(user.active_for_authentication?).to be false
    end

    it "returns false when locked" do
      user = create(:user, locked: true)
      expect(user.active_for_authentication?).to be false
    end
  end

  describe "#first_name_or_email" do
    it "returns person first_name when person exists" do
      person = create(:person, first_name: "Jane")
      expect(person.user.first_name_or_email).to eq("Jane")
    end

    it "returns email when no person" do
      user = create(:user)
      expect(user.first_name_or_email).to eq(user.email)
    end
  end

  describe "#deletable?" do
    it "returns true when user has no created records" do
      user = create(:user)
      expect(user.deletable?).to be true
    end

    it "returns false when user has created reports" do
      report = create(:report, workshop: create(:workshop))
      expect(report.created_by.deletable?).to be false
    end

    it "returns false when user has created workshops" do
      workshop = create(:workshop)
      expect(workshop.created_by.deletable?).to be false
    end

    it "returns false when user has created resources" do
      resource = create(:resource)
      expect(resource.created_by.deletable?).to be false
    end
  end

  describe '.search_by_params' do
    let!(:admin_user) { create(:user, email: 'alice@example.com', super_user: true) }
    let!(:regular_user) { create(:user, email: 'bob@example.com', super_user: false) }
    let!(:inactive_user) { create(:user, email: 'carol@example.com', inactive: true) }
    let!(:locked_user) { create(:user, email: 'dave@example.com', locked_at: Time.current) }

    it 'returns all when no params' do
      results = User.search_by_params({})
      expect(results).to include(admin_user, regular_user, inactive_user, locked_user)
    end

    it 'filters by search term matching email' do
      results = User.search_by_params(search: 'alice@example')
      expect(results).to include(admin_user)
      expect(results).not_to include(regular_user)
    end

    it 'filters by search term matching another email' do
      results = User.search_by_params(search: 'bob@example')
      expect(results).to include(regular_user)
      expect(results).not_to include(admin_user)
    end

    it 'filters by super_user' do
      results = User.search_by_params(super_user: 'true')
      expect(results).to include(admin_user)
      expect(results).not_to include(regular_user)
    end

    it 'filters by access true (has access)' do
      results = User.search_by_params(access: 'true')
      expect(results).to include(admin_user, regular_user)
      expect(results).not_to include(inactive_user, locked_user)
    end

    it 'filters by access false (no access)' do
      results = User.search_by_params(access: 'false')
      expect(results).to include(inactive_user, locked_user)
      expect(results).not_to include(admin_user, regular_user)
    end

    it 'chains search and super_user filters' do
      results = User.search_by_params(search: 'alice', super_user: 'true')
      expect(results).to include(admin_user)
      expect(results).not_to include(regular_user, inactive_user)
    end
  end

  describe "#track_password_changed" do
    let(:user) { create(:user, password: "original_password") }

    it "tracks auth.password_changed when encrypted_password changes" do
      expect(Analytics::LifecycleBuffer).to receive(:push).with(
        hash_including(name: "auth.password_changed")
      )

      user.update!(password: "new_secure_password", password_confirmation: "new_secure_password")
    end

    it "does not track when other fields change" do
      expect(Analytics::LifecycleBuffer).not_to receive(:push).with(
        hash_including(name: "auth.password_changed")
      )

      user.update!(first_name: "Updated")
    end
  end

  describe "#create_email_changed_notification" do
    let(:user) { create(:user, email: "old@example.com") }

    it "creates an account_email_changed notification when email changes" do
      user.skip_reconfirmation!

      expect {
        user.update!(email: "changed@example.com")
      }.to change(Notification, :count).by(1)

      notification = Notification.last
      expect(notification.kind).to eq("account_email_changed")
      expect(notification.recipient_role).to eq("person")
      expect(notification.recipient_email).to eq("changed@example.com")
      expect(notification.noticeable).to eq(user)
      expect(notification.delivered_at).to be_nil
    end

    it "does not create notification when email does not change" do
      expect {
        user.update!(first_name: "Updated")
      }.not_to change(Notification, :count)
    end
  end

  describe "#track_email_change" do
    let(:user) { create(:user, email: "old@example.com") }

    it "tracks auth.email_changed when email is confirmed" do
      user.skip_reconfirmation!

      expect(Analytics::LifecycleBuffer).to receive(:push).with(
        hash_including(
          name: "auth.email_changed",
          properties: hash_including(changes: { email: { before: "old@example.com", after: "new@example.com" } })
        )
      )

      user.update!(email: "new@example.com")
    end

    it "tracks auth.email_update_requested when unconfirmed_email is set" do
      expect(Analytics::LifecycleBuffer).to receive(:push).with(
        hash_including(
          name: "auth.email_update_requested",
          properties: hash_including(changes: { email: { before: "old@example.com", after: "pending@example.com" } })
        )
      )

      user.email = "pending@example.com"
      user.skip_confirmation_notification!
      user.save!
    end
  end

  describe "#send_confirmation_instructions" do
    let(:mock_mail) { double(deliver_later: true, deliver: true) }

    context "when there is no pending email change" do
      let(:user) { create(:user, confirmed_at: nil) }

      before do
        user # force creation before stubbing so on-create confirmation isn't counted
        allow(DeviseMailer).to receive(:confirmation_instructions).and_return(mock_mail)
      end

      it "sends to the current email" do
        user.send_confirmation_instructions

        expect(DeviseMailer).to have_received(:confirmation_instructions)
          .with(user, anything, hash_including(to: user.email))
      end
    end

    context "when there is a pending email change" do
      let(:user) { create(:user) }
      let(:new_email) { "pending@example.com" }

      before do
        user.update_columns(unconfirmed_email: new_email)
        allow(DeviseMailer).to receive(:confirmation_instructions).and_return(mock_mail)
      end

      it "sends to the pending email" do
        user.send_confirmation_instructions

        expect(DeviseMailer).to have_received(:confirmation_instructions)
          .with(user, anything, hash_including(to: new_email))
      end

      it "does not send to the current email" do
        user.send_confirmation_instructions

        expect(DeviseMailer).not_to have_received(:confirmation_instructions)
          .with(user, anything, hash_including(to: user.email))
      end
    end
  end
end
