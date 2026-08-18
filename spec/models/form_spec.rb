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
    # Add validation tests if any
    # subject { build(:form) } # Requires owner
    # it { should validate_presence_of(:owner_id) }
    # it { should validate_presence_of(:owner_type) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs owner association uncommented for create
  #   # expect(build(:form)).to be_valid
  #   pending("Requires functional owner factory and association uncommented")
  # end

  describe ".where(role: 'scholarship')" do
    it "returns only forms with scholarship role" do
      regular_form = create(:form)
      scholarship_form = create(:form, role: "scholarship")

      expect(Form.where(role: "scholarship")).to include(scholarship_form)
      expect(Form.where(role: "scholarship")).not_to include(regular_form)
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
