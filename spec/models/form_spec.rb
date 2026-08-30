require 'rails_helper'

RSpec.describe Form do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:owner).optional } # Polymorphic, optional for standalone forms
    it { should have_many(:event_forms).dependent(:destroy) }
    it { should have_many(:events).through(:event_forms) }
    it { should have_many(:form_fields).dependent(:destroy).inverse_of(:form) }
    it { should have_many(:user_forms) }
    it { should have_many(:form_submissions) }
    it { should have_many(:reports) } # As :owner

    it { should accept_nested_attributes_for(:form_fields).allow_destroy(true) }
  end

  describe 'validations' do
    describe 'role' do
      it 'accepts every value in Form::ROLES' do
        Form::ROLES.each do |role|
          expect(build(:form, role: role)).to be_valid, "expected role #{role.inspect} to be valid"
        end
      end

      it 'rejects a role outside Form::ROLES' do
        form = build(:form, role: "nonsense")
        expect(form).not_to be_valid
        expect(form.errors[:role]).to be_present
      end

      it 'allows a blank role (nil or "") so legacy forms save untouched' do
        expect(build(:form, role: nil)).to be_valid
        expect(build(:form, role: "")).to be_valid
      end
    end
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs owner association uncommented for create
  #   # expect(build(:form)).to be_valid
  #   pending("Requires functional owner factory and association uncommented")
  # end

  describe ".agreement_forms (agreement scenarios by role)" do
    it "returns publicly fillable forms with an agreement role" do
      on_demand = create(:form, role: "registration", slug: "collab", published: true)
      new_job = create(:form, role: "new_job", slug: "collab-new-job", published: true)

      expect(Form.agreement_forms).to contain_exactly(on_demand, new_job)
    end

    it "excludes unpublished, event-connected, and non-agreement-role forms" do
      create(:form, role: "new_job", slug: "draft", published: false)
      create(:form, role: "scholarship", slug: "scholarship", published: true)
      connected = create(:form, role: "registration", slug: "event-reg")
      create(:event_form, form: connected)

      expect(Form.agreement_forms).to be_empty
    end
  end

  describe ".owned / .standalone" do
    it "owned returns only owner-attached forms; standalone returns the rest" do
      builder = create(:form_builder)
      attached = create(:form, owner: builder)
      loose = create(:form, :standalone)

      expect(Form.owned).to contain_exactly(attached)
      expect(Form.standalone).to include(loose)
      expect(Form.standalone).not_to include(attached)
    end
  end

  describe ".where(role: 'scholarship')" do
    it "returns only forms with scholarship role" do
      regular_form = create(:form)
      scholarship_form = create(:form, role: "scholarship")

      expect(Form.where(role: "scholarship")).to include(scholarship_form)
      expect(Form.where(role: "scholarship")).not_to include(regular_form)
    end
  end

  describe "#accepts_anonymous_submissions?" do
    let(:form) { create(:form) }

    it "is true when the name/email questions are all optional" do
      create(:form_field, form: form, field_identifier: "first_name", required: false)
      create(:form_field, form: form, field_identifier: "last_name", required: false)
      create(:form_field, form: form, field_identifier: "primary_email", required: false)

      expect(form.reload.accepts_anonymous_submissions?).to be(true)
    end

    it "is false when any identity question is required" do
      create(:form_field, form: form, field_identifier: "first_name", required: false)
      create(:form_field, form: form, field_identifier: "primary_email", required: true)

      expect(form.reload.accepts_anonymous_submissions?).to be(false)
    end

    it "is false when the form asks for no identity questions at all" do
      create(:form_field, form: form, field_identifier: "why_volunteer", required: false)

      expect(form.reload.accepts_anonymous_submissions?).to be(false)
    end

    Form::AGREEMENT_ROLES.each do |role|
      it "is false for a #{role} agreement form even when its identity questions are optional" do
        agreement = create(:form, role: role)
        create(:form_field, form: agreement, field_identifier: "first_name", required: false)
        create(:form_field, form: agreement, field_identifier: "last_name", required: false)
        create(:form_field, form: agreement, field_identifier: "primary_email", required: false)

        expect(agreement.reload.accepts_anonymous_submissions?).to be(false)
      end
    end
  end

  describe "#requires_answer?" do
    Form::AGREEMENT_ROLES.each do |role|
      it "forces identity questions on a #{role} agreement form even when flagged optional" do
        agreement = create(:form, role: role)
        email = create(:form_field, form: agreement, field_identifier: "primary_email", required: false)
        other = create(:form_field, form: agreement, field_identifier: "why_volunteer", required: false)

        expect(agreement.requires_answer?(email)).to be(true)
        expect(agreement.requires_answer?(other)).to be(false)
      end
    end

    it "defers to the field's own required flag on a non-agreement form" do
      general = create(:form)
      email = create(:form_field, form: general, field_identifier: "primary_email", required: false)

      expect(general.requires_answer?(email)).to be(false)
    end
  end

  describe '#display_name' do
    let(:user_owner) do
      create(:user)
    end
    let(:form) { build(:form, owner: user_owner) }

    context 'when name is set' do
      it 'returns the name' do
        form.name = "Public Registration"
        expect(form.display_name).to eq("Public Registration")
      end
    end

    context 'when name is blank and owner is present' do
      it 'returns owner name Form' do
        form.name = nil
        owner_name = user_owner.try(:name) || user_owner.email
        expect(form.display_name).to eq("#{owner_name} Form")
      end
    end

    context 'when name is blank and owner is nil' do
      it 'returns New Form' do
        form.name = nil
        form.owner = nil
        expect(form.display_name).to eq('New Form')
      end
    end
  end

  describe 'slug + publishing' do
    it 'normalizes a slug to url-safe form' do
      form = create(:form, slug: 'Volunteer Interest!')
      expect(form.slug).to eq('volunteer-interest')
    end

    it 'stores a blank slug as nil so the uniqueness index tolerates many' do
      form = create(:form, slug: '')
      expect(form.slug).to be_nil
    end

    it 'stores a whitespace-only slug as nil' do
      form = create(:form, slug: '   ')
      expect(form.slug).to be_nil
    end

    it 'rejects a slug with no url-safe characters rather than blanking it' do
      form = build(:form, slug: '!!!')

      expect(form).not_to be_valid
      expect(form.errors[:slug]).to include('may only contain lowercase letters, numbers, and hyphens')
    end

    it 'rejects a duplicate slug' do
      create(:form, slug: 'apply')
      dup = build(:form, slug: 'apply')
      expect(dup).not_to be_valid
    end

    it 'requires a slug to publish' do
      form = build(:form, published: true, slug: nil)
      expect(form).not_to be_valid
      expect(form.errors[:slug]).to include('is required to publish a form')
    end

    describe '#publicly_fillable?' do
      it 'is true for a standalone, published, slugged form' do
        form = create(:form, slug: 'apply', published: true)
        expect(form).to be_publicly_fillable
      end

      it 'is false when not published' do
        form = create(:form, slug: 'apply', published: false)
        expect(form).not_to be_publicly_fillable
      end

      it 'is false when owned by an event/other record' do
        form = create(:form, :with_owner, slug: 'apply')
        form.update_column(:published, true)
        expect(form).not_to be_publicly_fillable
      end

      it 'is false when connected to an event' do
        form = create(:form, slug: 'apply', published: true)
        create(:event_form, form: form)
        expect(form.reload).not_to be_publicly_fillable
      end
    end

    it 'rejects publishing a form connected to an event' do
      form = create(:form, slug: 'apply')
      create(:event_form, form: form)
      form.published = true

      expect(form).not_to be_valid
      expect(form.errors[:published]).to include("can't be enabled for a form connected to an event")
    end

    describe '.published scope' do
      it 'returns only published forms' do
        published = create(:form, slug: 'a', published: true)
        create(:form, slug: 'b', published: false)
        expect(Form.published).to contain_exactly(published)
      end
    end
  end
end
