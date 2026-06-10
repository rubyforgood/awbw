require 'rails_helper'

RSpec.describe FormFieldAnswerOption do
  describe 'associations' do
    it { should belong_to(:form_field) }
    it { should belong_to(:answer_option) }
  end

  describe '#option_name' do
    it 'returns the linked answer option name' do
      join = build(:form_field_answer_option, answer_option: build(:answer_option, name: "Yes"))
      expect(join.option_name).to eq("Yes")
    end

    it 'is nil when no answer option is linked' do
      expect(FormFieldAnswerOption.new.option_name).to be_nil
    end
  end

  describe '#option_name=' do
    it 'links to an existing answer option with the same name instead of creating a duplicate' do
      existing = create(:answer_option, name: "Personal")
      join = build(:form_field_answer_option)

      expect { join.option_name = "Personal" }.not_to change(AnswerOption, :count)
      expect(join.answer_option).to eq(existing)
    end

    it 'creates a new answer option when none matches' do
      join = build(:form_field_answer_option)

      expect { join.option_name = "Brand New" }.to change(AnswerOption, :count).by(1)
      expect(join.answer_option.name).to eq("Brand New")
    end

    it 're-points to a different answer option rather than renaming the shared one' do
      shared = create(:answer_option, name: "Work")
      join = create(:form_field_answer_option, answer_option: shared)

      join.option_name = "Home"

      expect(shared.reload.name).to eq("Work")
      expect(join.answer_option.name).to eq("Home")
    end

    it 'strips surrounding whitespace' do
      join = build(:form_field_answer_option)
      join.option_name = "  Spaced  "
      expect(join.answer_option.name).to eq("Spaced")
    end
  end
end
