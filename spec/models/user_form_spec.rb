# frozen_string_literal: true

require "rails_helper"

RSpec.describe(UserForm) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:user)) }
    it { is_expected.to(belong_to(:form)) }
    it { is_expected.to(have_many(:user_form_form_fields)) }
    it { is_expected.to(accept_nested_attributes_for(:user_form_form_fields)) }
  end

  # it 'is valid with valid attributes' do
  #   # Note: Factory needs associations uncommented for create
  #   # expect(build(:user_form)).to be_valid
  #   pending("Requires functional user/form factories and associations uncommented")
  # end
end
