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

    # Paperclip avatar
    # it { should have_attached_file(:avatar) }

    # Nested Attributes
    it { should accept_nested_attributes_for(:user_forms) }
  end

  describe "strip_whitespace" do
    it "strips leading and trailing whitespace from names and email" do
      user = create(:user, first_name: "  Jane  ", last_name: "  Doe  ", email: "  jane@test.org  ")
      expect(user.first_name).to eq("Jane")
      expect(user.last_name).to eq("Doe")
      expect(user.email).to eq("jane@test.org")
    end

    it "handles nil name values" do
      user = create(:user, first_name: nil, last_name: nil, email: "nil-names@test.org")
      expect(user.first_name).to be_nil
      expect(user.last_name).to be_nil
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
    # These tests remain relevant
    let(:user) { build(:user) }
    context "when first_name is present" do
      it "returns the full name" do
        user.first_name = "John"
        user.last_name = "Doe"
        expect(user.full_name).to eq("John Doe")
      end
    end

    context "when first_name is nil" do
      it "returns the email" do
        user.first_name = nil
        expect(user.full_name).to eq(user.email)
      end
    end

    context "when first_name is empty" do
      it "returns the email" do
        user.first_name = ""
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
      user.first_name = "Updated"
      expect(user).to be_valid
    end

    it "allows user without person_id to remain without one" do
      user = create(:user)
      user.first_name = "Updated"
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

  describe "#full_name" do
    context "when user has a person" do
      it "returns the person's full name" do
        person = create(:person, first_name: "Jane", last_name: "Doe")
        expect(person.user.full_name).to eq("Jane Doe")
      end
    end

    context "when user has no person but has first_name" do
      it "returns user's own full name" do
        user = create(:user, first_name: "Bob", last_name: "Smith")
        expect(user.full_name).to eq("Bob Smith")
      end
    end

    context "when user has no person and no first_name" do
      it "returns the email" do
        user = create(:user, first_name: nil)
        expect(user.full_name).to eq(user.email)
      end
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

  describe "#devise_email_name" do
    it "returns person first_name when person exists" do
      person = create(:person, first_name: "Jane")
      expect(person.user.devise_email_name).to eq("Jane")
    end

    it "returns user first_name when no person" do
      user = create(:user, first_name: "Bob")
      expect(user.devise_email_name).to eq("Bob")
    end

    it "returns email when no name available" do
      user = create(:user, first_name: nil)
      expect(user.devise_email_name).to eq(user.email)
    end
  end
end
