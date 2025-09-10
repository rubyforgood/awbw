# frozen_string_literal: true

require "rails_helper"

RSpec.describe(FormFieldAnswerOption) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:form_field)) }
    it { is_expected.to(belong_to(:answer_option)) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs associations uncommented for create
  #   # expect(build(:form_field_answer_option)).to be_valid
  #   pending("Requires functional form_field/answer_option factories and associations uncommented")
  # end
end
