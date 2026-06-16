require 'rails_helper'

RSpec.describe FormField do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe 'associations' do
    it { should belong_to(:form).inverse_of(:form_fields) }
    it { should have_many(:form_field_answer_options).dependent(:destroy) }
    it { should have_many(:report_form_field_answers).dependent(:destroy) }
    it { should have_many(:answer_options).through(:form_field_answer_options) }
    it { should have_many(:childs).class_name('FormField').with_foreign_key('parent_id') }
    # belongs_to :parent is implied but not explicitly stated, test if needed
    # it { should belong_to(:parent).class_name('FormField').optional }

    it { should accept_nested_attributes_for(:form_field_answer_options) }
  end

  describe 'validations' do
    # Requires form association for create
    subject do
      build(:form_field, form: create(:form))
    end
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(1000) }

    it "accepts a long, multi-sentence question name" do
      field = build(:form_field, form: create(:form), name: "A. " * 100)
      expect(field).to be_valid
    end

    describe "required flag on display-only types" do
      let(:form) { create(:form) }

      %i[no_user_input group_header].each do |type|
        it "rejects a required #{type} field" do
          field = build(:form_field, form: form, answer_type: type, required: true)
          expect(field).not_to be_valid
          expect(field.errors[:required]).to be_present
        end

        it "allows a non-required #{type} field" do
          field = build(:form_field, form: form, answer_type: type, required: false)
          expect(field).to be_valid
        end
      end

      it "still allows a required input field" do
        field = build(:form_field, form: form, answer_type: :free_form_input_one_line, required: true)
        expect(field).to be_valid
      end
    end
  end

  describe "#collects_input?" do
    let(:form) { create(:form) }

    %i[no_user_input group_header].each do |type|
      it "is false for #{type}" do
        expect(build(:form_field, form: form, answer_type: type).collects_input?).to be false
      end
    end

    %i[free_form_input_one_line single_select_radio multi_select_checkbox].each do |type|
      it "is true for #{type}" do
        expect(build(:form_field, form: form, answer_type: type).collects_input?).to be true
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values([ :inactive, :active ]) }
    it { should define_enum_for(:answer_type).with_values([ :free_form_input_one_line, :free_form_input_paragraph,
                                                           :single_select_radio, :no_user_input, :multi_select_checkbox,
                                                           :group_header, :single_select_dropdown ]) }
    it { should define_enum_for(:input_type).with_values([ :text_alphanumeric, :number_integer, :number_decimal, :date ]) }
  end

  describe "enums" do
    it { should define_enum_for(:visibility).with_values([ :always_ask, :scholarship_only, :logged_out_only, :answers_on_file ]) }
    it { should define_enum_for(:width).with_values([ :full, :half, :third, :quarter ]).with_prefix(true) }
  end

  describe "#grid_span_class" do
    let(:form) { create(:form) }

    it "spans the full grid for full-width fields" do
      field = build(:form_field, form: form, width: :full)
      expect(field.grid_span_class).to eq("md:col-span-12")
    end

    it "spans half the grid for half-width fields" do
      field = build(:form_field, form: form, width: :half)
      expect(field.grid_span_class).to eq("md:col-span-6")
    end

    it "spans a third of the grid for third-width fields" do
      field = build(:form_field, form: form, width: :third)
      expect(field.grid_span_class).to eq("md:col-span-4")
    end

    it "spans a quarter of the grid for quarter-width fields" do
      field = build(:form_field, form: form, width: :quarter)
      expect(field.grid_span_class).to eq("md:col-span-3")
    end

    it "falls back to full width when width is blank" do
      field = build(:form_field, form: form)
      field.width = nil
      expect(field.grid_span_class).to eq("md:col-span-12")
    end
  end

  describe "#visibility_label" do
    let(:form) { create(:form) }

    it "returns the human-friendly label for each visibility" do
      expect(build(:form_field, form: form, visibility: :always_ask).visibility_label).to eq("Always ask")
      expect(build(:form_field, form: form, visibility: :scholarship_only).visibility_label).to eq("Scholarship only")
      expect(build(:form_field, form: form, visibility: :logged_out_only).visibility_label).to eq("Logged out only")
      expect(build(:form_field, form: form, visibility: :answers_on_file).visibility_label).to eq("Answers on file")
    end
  end

  describe "#conditional_visibility?" do
    let(:form) { create(:form) }

    it "is false for always-ask fields" do
      expect(build(:form_field, form: form, visibility: :always_ask).conditional_visibility?).to be false
    end

    it "is true for any non-always-ask visibility" do
      expect(build(:form_field, form: form, visibility: :logged_out_only).conditional_visibility?).to be true
      expect(build(:form_field, form: form, visibility: :answers_on_file).conditional_visibility?).to be true
      expect(build(:form_field, form: form, visibility: :scholarship_only).conditional_visibility?).to be true
    end
  end

  describe "#min_words_error" do
    let(:form) { create(:form) }

    it "returns nil when no minimum is configured" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: nil)
      expect(field.min_words_error("just two")).to be_nil
    end

    it "returns nil when the value meets the minimum" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 3)
      expect(field.min_words_error("one two three")).to be_nil
    end

    it "ignores surrounding and repeated whitespace when counting" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 3)
      expect(field.min_words_error("  one\ntwo   three  ")).to be_nil
    end

    it "returns an error when the value has too few words" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 5)
      expect(field.min_words_error("only three words")).to eq("must be at least 5 words")
    end

    it "pluralizes the word count for a minimum of one" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 1)
      expect(field.min_words_error("")).to be_nil
      expect(field.min_words_error("   ")).to be_nil
    end

    it "leaves blank values to the required check" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 5)
      expect(field.min_words_error("")).to be_nil
      expect(field.min_words_error(nil)).to be_nil
    end

    it "does not apply to non-text answer types" do
      field = build(:form_field, form: form, answer_type: :single_select_radio, min_words: 5)
      expect(field.min_words_error("Yes")).to be_nil
    end
  end

  describe "min_words validation" do
    let(:form) { create(:form) }

    it "rejects a negative minimum" do
      field = build(:form_field, form: form, min_words: -1)
      expect(field).not_to be_valid
    end

    it "allows a nil minimum" do
      field = build(:form_field, form: form, min_words: nil)
      expect(field).to be_valid
    end
  end

  describe "#effective_max_characters" do
    let(:form) { create(:form) }

    it "returns the explicit maximum when one is set" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, max_characters: 250)
      expect(field.effective_max_characters).to eq(250)
    end

    it "honors an explicit maximum larger than the default" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, max_characters: 50_000)
      expect(field.effective_max_characters).to eq(50_000)
    end

    it "falls back to the per-type default when none is set" do
      one_line = build(:form_field, form: form, answer_type: :free_form_input_one_line, max_characters: nil)
      paragraph = build(:form_field, form: form, answer_type: :free_form_input_paragraph, max_characters: nil)
      expect(one_line.effective_max_characters).to eq(FormField::DEFAULT_MAX_CHARACTERS["free_form_input_one_line"])
      expect(paragraph.effective_max_characters).to eq(FormField::DEFAULT_MAX_CHARACTERS["free_form_input_paragraph"])
    end

    it "returns nil for non-free-form fields" do
      field = build(:form_field, form: form, answer_type: :single_select_radio, max_characters: nil)
      expect(field.effective_max_characters).to be_nil
    end
  end

  describe "#max_characters_error" do
    let(:form) { create(:form) }

    it "applies the per-type default safety net when no maximum is configured" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, max_characters: nil)
      default = FormField::DEFAULT_MAX_CHARACTERS["free_form_input_paragraph"]
      expect(field.max_characters_error("a" * default)).to be_nil
      expect(field.max_characters_error("a" * (default + 1))).to eq("must be #{default} characters or fewer")
    end

    it "returns nil when the value is within the maximum" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, max_characters: 10)
      expect(field.max_characters_error("short")).to be_nil
    end

    it "returns nil when the value is exactly at the maximum" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, max_characters: 5)
      expect(field.max_characters_error("12345")).to be_nil
    end

    it "returns an error when the value exceeds the maximum" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, max_characters: 5)
      expect(field.max_characters_error("123456")).to eq("must be 5 characters or fewer")
    end

    it "pluralizes correctly for a maximum of one" do
      field = build(:form_field, form: form, answer_type: :free_form_input_one_line, max_characters: 1)
      expect(field.max_characters_error("ab")).to eq("must be 1 character or fewer")
    end

    it "leaves blank values to the required check" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, max_characters: 5)
      expect(field.max_characters_error("")).to be_nil
      expect(field.max_characters_error(nil)).to be_nil
    end

    it "does not apply to non-text answer types" do
      field = build(:form_field, form: form, answer_type: :single_select_radio, max_characters: 1)
      expect(field.max_characters_error("Yes")).to be_nil
    end
  end

  describe "max_characters validation" do
    let(:form) { create(:form) }

    it "rejects a zero maximum" do
      field = build(:form_field, form: form, max_characters: 0)
      expect(field).not_to be_valid
    end

    it "rejects a negative maximum" do
      field = build(:form_field, form: form, max_characters: -1)
      expect(field).not_to be_valid
    end

    it "allows a nil maximum" do
      field = build(:form_field, form: form, max_characters: nil)
      expect(field).to be_valid
    end
  end

  describe "min_words / max_characters consistency" do
    let(:form) { create(:form) }

    it "rejects a max too small to hold the word minimum" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 250, max_characters: 1_000)
      expect(field).not_to be_valid
      expect(field.errors[:max_characters]).to include("is too low for a 250-word minimum (allow at least 1500)")
    end

    it "allows a max with room for the word minimum" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 250, max_characters: 2_000)
      expect(field).to be_valid
    end

    it "allows the exact boundary" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 10, max_characters: 60)
      expect(field).to be_valid
    end

    it "does not flag when only one of the two is set" do
      min_only = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 250, max_characters: nil)
      max_only = build(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: nil, max_characters: 50)
      expect(min_only).to be_valid
      expect(max_only).to be_valid
    end

    it "does not apply to non-free-form fields" do
      field = build(:form_field, form: form, answer_type: :single_select_radio, min_words: 250, max_characters: 1)
      expect(field).to be_valid
    end
  end

  describe "#answer_inclusion_error" do
    let(:form) { create(:form) }

    def selectable_field(type:, option_names:)
      field = create(:form_field, form: form, answer_type: type)
      option_names.each do |name|
        create(:form_field_answer_option, form_field: field, answer_option: create(:answer_option, name: name))
      end
      field
    end

    it "returns nil for a value that is one of the offered options" do
      field = selectable_field(type: :single_select_radio, option_names: %w[Red Blue])
      expect(field.answer_inclusion_error("Red")).to be_nil
    end

    it "returns an error for a value that was never offered" do
      field = selectable_field(type: :single_select_radio, option_names: %w[Red Blue])
      expect(field.answer_inclusion_error("Green")).to eq("has an invalid selection")
    end

    it "leaves blank values to the required check" do
      field = selectable_field(type: :single_select_radio, option_names: %w[Red Blue])
      expect(field.answer_inclusion_error("")).to be_nil
      expect(field.answer_inclusion_error(nil)).to be_nil
    end

    it "validates every value in a multi-select answer" do
      field = selectable_field(type: :multi_select_checkbox, option_names: %w[Red Blue Green])
      expect(field.answer_inclusion_error([ "Red", "Blue" ])).to be_nil
      expect(field.answer_inclusion_error([ "Red", "Purple" ])).to eq("has an invalid selection")
    end

    it "accepts an Other free-text answer when the field offers Other" do
      field = selectable_field(type: :single_select_radio, option_names: [ "Red", "Other" ])
      expect(field.answer_inclusion_error("Other")).to be_nil
      expect(field.answer_inclusion_error("Other: chartreuse")).to be_nil
    end

    it "rejects an Other answer when the field does not offer Other" do
      field = selectable_field(type: :single_select_radio, option_names: %w[Red Blue])
      expect(field.answer_inclusion_error("Other: chartreuse")).to eq("has an invalid selection")
    end

    it "does not apply to free-form fields" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph)
      expect(field.answer_inclusion_error("anything at all")).to be_nil
    end

    context "with dynamically-sourced options" do
      it "accepts a published Sector id and rejects others for a service-area field" do
        field = create(:form_field, form: form, answer_type: :single_select_dropdown, field_identifier: "primary_service_area_single")
        offered = create(:sector, :published)
        unpublished = create(:sector, :unpublished)

        expect(field.answer_inclusion_error(offered.id.to_s)).to be_nil
        expect(field.answer_inclusion_error(unpublished.id.to_s)).to eq("has an invalid selection")
        expect(field.answer_inclusion_error("999999")).to eq("has an invalid selection")
      end

      it "accepts a published Category id from the backing type for a category field" do
        type = create(:category_type, name: "WorkshopEnvironment")
        offered = create(:category, :published, category_type: type)
        other_type_category = create(:category, :published)
        field = create(:form_field, form: form, answer_type: :multi_select_checkbox, field_identifier: "workshop_environments")

        expect(field.answer_inclusion_error([ offered.id.to_s ])).to be_nil
        expect(field.answer_inclusion_error([ other_type_category.id.to_s ])).to eq("has an invalid selection")
      end
    end
  end

  describe "#selectable?" do
    let(:form) { create(:form) }

    it "returns true for checkbox fields" do
      field = build(:form_field, form: form, answer_type: :multi_select_checkbox)
      expect(field.selectable?).to be true
    end

    it "returns true for radio fields" do
      field = build(:form_field, form: form, answer_type: :single_select_radio)
      expect(field.selectable?).to be true
    end

    it "returns false for text fields" do
      field = build(:form_field, form: form, answer_type: :free_form_input_one_line)
      expect(field.selectable?).to be false
    end
  end

  describe "#html_input_type" do
    let(:form) { create(:form) }

    it "returns :text for one-line inputs" do
      field = build(:form_field, form: form, answer_type: :free_form_input_one_line)
      expect(field.html_input_type).to eq(:text)
    end

    it "returns :textarea for paragraphs" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph)
      expect(field.html_input_type).to eq(:textarea)
    end

    it "returns :checkbox for checkbox fields" do
      field = build(:form_field, form: form, answer_type: :multi_select_checkbox)
      expect(field.html_input_type).to eq(:checkbox)
    end

    it "returns :radio for radio fields" do
      field = build(:form_field, form: form, answer_type: :single_select_radio)
      expect(field.html_input_type).to eq(:radio)
    end

    it "returns :label for no_user_input without children" do
      field = build(:form_field, form: form, answer_type: :no_user_input)
      expect(field.html_input_type).to eq(:label)
    end

    it "returns :label for group_header without children" do
      field = build(:form_field, form: form, answer_type: :group_header)
      expect(field.html_input_type).to eq(:label)
    end
  end

  describe "#form_helper_type" do
    let(:form) { create(:form) }

    it "returns :text_field for one-line inputs" do
      field = build(:form_field, form: form, answer_type: :free_form_input_one_line)
      expect(field.form_helper_type).to eq(:text_field)
    end

    it "returns :text_area for paragraphs" do
      field = build(:form_field, form: form, answer_type: :free_form_input_paragraph)
      expect(field.form_helper_type).to eq(:text_area)
    end

    it "returns :check_box for checkbox fields" do
      field = build(:form_field, form: form, answer_type: :multi_select_checkbox)
      expect(field.form_helper_type).to eq(:check_box)
    end

    it "returns :radio_button for radio fields" do
      field = build(:form_field, form: form, answer_type: :single_select_radio)
      expect(field.form_helper_type).to eq(:radio_button)
    end
  end

  describe "#answer_type_label" do
    let(:form) { create(:form) }

    it "calls radio fields single select" do
      field = build(:form_field, form: form, answer_type: :single_select_radio)
      expect(field.answer_type_label).to eq("Single select radio")
    end

    it "calls checkbox fields multiple select" do
      field = build(:form_field, form: form, answer_type: :multi_select_checkbox)
      expect(field.answer_type_label).to eq("Multiple select checkbox")
    end

    it "falls back to a humanized label for unmapped types" do
      field = build(:form_field, form: form, answer_type: :free_form_input_one_line)
      expect(field.answer_type_label).to eq("One line")
    end
  end
end
