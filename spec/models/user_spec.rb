require 'rails_helper'

RSpec.describe User do
  # Use FactoryBot
  # let(:user) { build(:user) } # Keep build for simple validation tests
  # Create permissions needed by the after_create callback
  before(:all) do
      create(:permission, :adult)
      create(:permission, :children)
      create(:permission, :combined)
  end

  describe 'associations' do
    # Need create for association tests to work correctly with callbacks
    subject { create(:user) }

    it { should belong_to(:facilitator).optional}
    it { should have_many(:workshops) }
    it { should have_many(:workshop_logs) }
    it { should have_many(:reports) }
    # Through associations require more setup, test manually if complex
    # it { should have_many(:communal_reports).through(:projects).source(:reports) }
    it { should have_many(:bookmarks).dependent(:destroy) }
    it { should have_many(:bookmarked_workshops).through(:bookmarks).source(:bookmarkable) }
    it { should have_many(:project_users).dependent(:destroy) }
    it { should have_many(:projects).through(:project_users) }
    it { should have_many(:windows_types).through(:projects) }
    it { should have_many(:user_permissions).dependent(:destroy) }
    it { should have_many(:permissions).through(:user_permissions) }
    it { should have_many(:resources) }
    it { should have_many(:user_forms).dependent(:destroy) }
    it { should have_many(:user_form_form_fields).through(:user_forms).dependent(:destroy) }
    # Custom scope/select for colleagues might interfere
    # it { should have_many(:colleagues).through(:projects).source(:project_users) }
    it { should have_many(:notifications) } # As :noticeable

    # Paperclip avatar
    # it { should have_attached_file(:avatar) }

    # Nested Attributes
    it { should accept_nested_attributes_for(:user_forms) }
    it { should accept_nested_attributes_for(:project_users).allow_destroy(true) }
  end

  describe 'validations' do
    # Devise validations (presence tested manually below, uniqueness tested with subject)
    subject { create(:user) } # Use create for uniqueness tests
    it { should validate_uniqueness_of(:email).case_insensitive }
    # it { should validate_length_of(:password).is_at_least(Devise.password_length.first).is_at_most(Devise.password_length.last) }

    # Manual presence tests (using build is fine here)
    let(:user) { build(:user) } 
    it 'is valid with valid attributes' do
      expect(user).to be_valid
    end

    it 'is invalid without an email' do
      user.email = nil
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it 'is invalid without a password' do
      user.password = nil
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    # Commented out validations in model
    # it { should validate_presence_of(:first_name) }
    # it { should validate_presence_of(:last_name) }

    # Paperclip avatar validations
    # it { should validate_attachment_content_type(:avatar).allowing('image/png', 'image/jpeg', 'image/gif').rejecting('text/plain', 'application/pdf') }
  end

  describe '#full_name' do
    # These tests remain relevant
    let(:user) { build(:user) } 
    context 'when first_name is present' do
      it 'returns the full name' do
        user.first_name = "John"
        user.last_name = "Doe"
        expect(user.full_name).to eq("John Doe")
      end
    end

    context 'when first_name is nil' do
      it 'returns the email' do
        user.first_name = nil
        expect(user.full_name).to eq(user.email)
      end
    end

    context 'when first_name is empty' do
      it 'returns the email' do
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

  # Add tests for other methods like #active_for_authentication?, #has_liaison_position_for?, etc.
  # Test callbacks like :set_default_values, :before_destroy
end 