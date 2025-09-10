# frozen_string_literal: true

require "rails_helper"

RSpec.describe(UserFormFormField) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:form_field)) }
    it { is_expected.to(belong_to(:user_form)) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs associations uncommented for create
  #   # expect(build(:user_form_form_field)).to be_valid
  #   pending("Requires functional form_field/user_form factories and associations uncommented")
  # end
end
