# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormAnswerValidator do
  let(:form) { create(:form) }

  def validate(field, value)
    described_class.call([ field ], { field.id.to_s => value })
  end

  describe "presence" do
    it "flags a blank value on a required field" do
      field = create(:form_field, form: form, required: true)

      expect(validate(field, "")).to eq(field.id => "can't be blank")
    end

    it "treats an array of only blanks as blank" do
      field = create(:form_field, form: form, required: true, answer_type: :multiple_choice_checkbox)

      expect(validate(field, [ "", "" ])).to eq(field.id => "can't be blank")
    end

    it "passes a present value on a required field" do
      field = create(:form_field, form: form, required: true)

      expect(validate(field, "Jane")).to eq({})
    end

    it "skips format checks when an optional field is left blank" do
      field = create(:form_field, form: form, required: false, input_type: :number_integer)

      expect(validate(field, "")).to eq({})
    end
  end

  describe "whole number format" do
    let(:field) { create(:form_field, form: form, input_type: :number_integer) }

    it "rejects non-integer input" do
      expect(validate(field, "12.5")).to eq(field.id => "must be a whole number")
    end

    it "accepts integer input" do
      expect(validate(field, "12")).to eq({})
    end
  end

  describe "email format" do
    let(:field) { create(:form_field, form: form, field_identifier: "primary_email") }

    it "rejects a malformed email" do
      expect(validate(field, "not-an-email")).to eq(field.id => "must be a valid email address")
    end

    it "accepts a well-formed email" do
      expect(validate(field, "jane@example.com")).to eq({})
    end

    it "checks payer_email the same way (unified across forms)" do
      payer = create(:form_field, form: form, field_identifier: "payer_email")

      expect(validate(payer, "nope")).to eq(payer.id => "must be a valid email address")
    end

    it "does not email-validate the *_type selector field" do
      type_field = create(:form_field, form: form, field_identifier: "secondary_email_type")

      expect(validate(type_field, "work")).to eq({})
    end

    it "does not email-validate a field whose identifier merely contains 'email'" do
      lookalike = create(:form_field, form: form, field_identifier: "email_preferences")

      expect(validate(lookalike, "anything")).to eq({})
    end
  end

  describe "min words / max characters" do
    it "surfaces the min-words error" do
      field = create(:form_field, form: form, answer_type: :free_form_input_paragraph, min_words: 3)

      expect(validate(field, "too short")).to eq(field.id => "must be at least 3 words")
    end

    it "surfaces the max-characters error" do
      field = create(:form_field, form: form, answer_type: :free_form_input_one_line, max_characters: 5)

      expect(validate(field, "way too long")).to eq(field.id => "must be 5 characters or fewer")
    end
  end

  describe "skipping" do
    it "ignores group header fields entirely" do
      header = create(:form_field, form: form, answer_type: :group_header, required: true)

      expect(validate(header, "")).to eq({})
    end
  end

  describe "merging multiple forms" do
    it "returns one entry per failing field, keyed by id" do
      a = create(:form_field, form: form, required: true)
      b = create(:form_field, form: form, input_type: :number_integer)

      result = described_class.call([ a, b ], { a.id.to_s => "", b.id.to_s => "x" })

      expect(result).to eq(a.id => "can't be blank", b.id => "must be a whole number")
    end
  end
end
