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

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs owner association uncommented for create
  #   # expect(build(:form)).to be_valid
  #   pending("Requires functional owner factory and association uncommented")
  # end

  describe ".agreement_forms (agreement scenarios by role)" do
    it "returns publicly fillable forms with an agreement role" do
      on_demand = create(:form, role: "registration", slug: "collab", published: true)
      reinstatement = create(:form, role: "reinstatement", slug: "collab-reinstatement", published: true)

      expect(Form.agreement_forms).to contain_exactly(on_demand, reinstatement)
    end

    it "excludes unpublished, event-connected, and non-agreement-role forms" do
      create(:form, role: "reinstatement", slug: "draft", published: false)
      create(:form, role: "scholarship", slug: "scholarship", published: true)
      connected = create(:form, role: "registration", slug: "event-reg")
      create(:event_form, form: connected)

      expect(Form.agreement_forms).to be_empty
    end
  end

  describe "survey roles" do
    it "allows many forms per survey role" do
      create(:form, role: "day_1_survey")
      expect(build(:form, role: "day_1_survey")).to be_valid
    end

    it "allows many general forms" do
      create(:form, role: "general")
      expect(build(:form, role: "general")).to be_valid
    end

    it "treats every role option naming a survey as a survey role, in dropdown order" do
      expect(Form::SURVEY_ROLES).to eq(%w[day_1_survey day_2_survey post_event_survey recipient_survey])
    end
  end

  describe ".survey" do
    it "returns the oldest standalone form with the role" do
      oldest = create(:form, role: "day_1_survey")
      create(:form, role: "day_1_survey")

      expect(Form.survey("day_1_survey")).to eq(oldest)
    end

    it "skips event-owned forms" do
      create(:form, role: "day_1_survey", owner: create(:event))
      standalone = create(:form, role: "day_1_survey")

      expect(Form.survey("day_1_survey")).to eq(standalone)
    end

    it "returns nil when no form has the role" do
      expect(Form.survey("day_2_survey")).to be_nil
    end
  end

  describe ".survey_default_ids" do
    it "lists the oldest standalone form for each survey role" do
      day_1 = create(:form, role: "day_1_survey")
      create(:form, role: "day_1_survey")
      post_event = create(:form, role: "post_event_survey")
      create(:form, role: "registration")
      create(:form, role: "day_2_survey", owner: create(:event))

      expect(Form.survey_default_ids).to contain_exactly(day_1.id, post_event.id)
    end
  end

  describe "#default_survey" do
    it "is the oldest standalone form sharing the survey role" do
      original = create(:form, role: "day_1_survey")
      copy = create(:form, role: "day_1_survey")

      expect(copy.default_survey).to eq(original)
      expect(original.default_survey).to eq(original)
    end

    it "is nil for a non-survey role or an event-owned form" do
      expect(create(:form, role: "registration").default_survey).to be_nil
      expect(create(:form, role: "day_1_survey", owner: create(:event)).default_survey).to be_nil
    end
  end

  describe ".survey_header" do
    it "uses the role's dropdown label" do
      expect(Form.survey_header("post_event_survey")).to eq("Post-event survey")
    end

    it "calls the recipients survey the scholarship survey" do
      expect(Form.survey_header("recipient_survey")).to eq("Scholarship survey")
    end

    it "humanizes a role outside the dropdown" do
      expect(Form.survey_header("legacy_survey")).to eq("Legacy survey")
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

  describe "anonymous" do
    it "defaults to off" do
      expect(create(:form).anonymous?).to be(false)
    end

    it "can be turned on for a survey or general form" do
      expect(build(:form, role: "post_event_survey", anonymous: true)).to be_valid
      expect(build(:form, role: "general", anonymous: true)).to be_valid
    end

    Form::IDENTIFIED_ROLES.each do |role|
      it "can't be turned on for a #{role} form, which is processed against a person" do
        form = build(:form, role:, anonymous: true)

        expect(form).not_to be_valid
        expect(form.errors[:anonymous]).to be_present
      end
    end

    describe "on the CE hours callout" do
      let(:form) { create(:form, anonymous: true) }

      before do
        create(:form_field, form:, name: "How was it?")
        create(:registration_ticket_callout, builtin_key: "ce_hours", form:)
      end

      it "can't be turned off" do
        form.anonymous = false

        expect(form).not_to be_valid
        expect(form.errors[:anonymous]).to include("must stay on for a CE hours evaluation")
      end

      it "can't gain a name or email question" do
        form.assign_attributes(form_fields_attributes: [ { name: "Email", field_identifier: "primary_email" } ])

        expect(form).not_to be_valid
        expect(form.errors[:base]).to include("A CE hours evaluation can't ask for a name or email")
      end

      it "can drop a name or email question it already asks" do
        email = form.form_fields.create!(name: "Email", field_identifier: "primary_email", answer_type: :free_form_input_one_line)
        form.reload.assign_attributes(form_fields_attributes: [ { id: email.id, _destroy: "1" } ])

        expect(form).to be_valid
      end
    end
  end

  describe "#requires_identity?" do
    it "is true unless the form is set to anonymous" do
      expect(build(:form).requires_identity?).to be(true)
      expect(build(:form, anonymous: true).requires_identity?).to be(false)
    end
  end

  describe "#missing_identity_questions?" do
    let(:form) { create(:form) }

    it "is true when a form not set to anonymous lacks any of first name, last name, or email" do
      create(:form_field, form:, field_identifier: "first_name")
      create(:form_field, form:, field_identifier: "last_name")

      expect(form.reload.missing_identity_questions?).to be(true)
    end

    it "is false once all three are asked" do
      Form::IDENTITY_IDENTIFIERS.each { |identifier| create(:form_field, form:, field_identifier: identifier) }

      expect(form.reload.missing_identity_questions?).to be(false)
    end

    it "is false for an anonymous form" do
      form.update!(anonymous: true)

      expect(form.missing_identity_questions?).to be(false)
    end
  end

  describe "#identified_by?" do
    let(:form) { create(:form, anonymous: true) }
    let!(:first_name) { create(:form_field, form:, field_identifier: "first_name") }
    let!(:last_name) { create(:form_field, form:, field_identifier: "last_name") }
    let!(:email) { create(:form_field, form:, field_identifier: "primary_email") }

    def params(first: "Sam", last: "Rivera", address: "sam@example.com")
      { first_name.id.to_s => first, last_name.id.to_s => last, email.id.to_s => address }
    end

    it "is true when first name, last name, and email are all answered" do
      expect(form.identified_by?(params)).to be(true)
    end

    it "is false when any one of the three is blank" do
      expect(form.identified_by?(params(first: ""))).to be(false)
      expect(form.identified_by?(params(last: ""))).to be(false)
      expect(form.identified_by?(params(address: ""))).to be(false)
    end

    it "is false for whitespace-only answers" do
      expect(form.identified_by?(params(first: " ", last: " ", address: " "))).to be(false)
    end

    it "is false when the params leave a question out" do
      expect(form.identified_by?(params.except(email.id.to_s))).to be(false)
    end

    it "is false when the form has no name and email questions" do
      bare = create(:form, anonymous: true)

      expect(bare.identified_by?(params)).to be(false)
    end

    it "accepts a legal first name in place of a first name" do
      legal = create(:form_field, form:, field_identifier: "legal_first_name")
      answers = params(first: "").merge(legal.id.to_s => "Samantha")

      expect(form.identified_by?(answers)).to be(true)
    end

    it "reads string or symbol keys" do
      expect(form.identified_by?(params.transform_keys(&:to_sym))).to be(true)
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

    it "never requires a name or email question on an anonymous form, even one flagged required" do
      anonymous = create(:form, anonymous: true)
      email = create(:form_field, form: anonymous, field_identifier: "primary_email", required: true)
      other = create(:form_field, form: anonymous, field_identifier: "why_volunteer", required: true)

      expect(anonymous.requires_answer?(email)).to be(false)
      expect(anonymous.requires_answer?(other)).to be(true)
    end

    it "forces the name and email questions on any form not set to anonymous" do
      general = create(:form)
      email = create(:form_field, form: general, field_identifier: "primary_email", required: false)
      other = create(:form_field, form: general, field_identifier: "why_volunteer", required: false)

      expect(general.requires_answer?(email)).to be(true)
      expect(general.requires_answer?(other)).to be(false)
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
