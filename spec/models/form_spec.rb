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

  describe 'section groups' do
    let(:form) do
      create(:form, :standalone, subsections: %w[person_identifier person_contact_info scholarship])
    end

    describe '#assign_section_groups!' do
      it 'groups subsections that share a label, preserving subsection order' do
        form.assign_section_groups!(
          "person_identifier" => "About you",
          "person_contact_info" => "About you",
          "scholarship" => "Funding"
        )

        expect(form.reload.sections).to eq([
          { "label" => "About you", "subsections" => %w[person_identifier person_contact_info] },
          { "label" => "Funding", "subsections" => %w[scholarship] }
        ])
      end

      it 'leaves subsections with a blank label ungrouped' do
        form.assign_section_groups!(
          "person_identifier" => "About you",
          "person_contact_info" => "  ",
          "scholarship" => ""
        )

        expect(form.reload.sections).to eq([
          { "label" => "About you", "subsections" => %w[person_identifier] }
        ])
      end
    end

    describe '#section_label_for_subsection' do
      before do
        form.assign_section_groups!(
          "person_identifier" => "About you",
          "person_contact_info" => "About you"
        )
      end

      it 'returns the section label for a grouped subsection' do
        expect(form.section_label_for_subsection("person_contact_info")).to eq("About you")
      end

      it 'returns nil for an ungrouped subsection' do
        expect(form.section_label_for_subsection("scholarship")).to be_nil
      end

      it 'returns nil for a blank subsection' do
        expect(form.section_label_for_subsection(nil)).to be_nil
      end
    end

    describe '#sections?' do
      it 'is false when no sections are defined' do
        expect(form.sections?).to be false
      end

      it 'is true once subsections are grouped' do
        form.assign_section_groups!("person_identifier" => "About you")
        expect(form.sections?).to be true
      end
    end
  end
end
