require "rails_helper"

RSpec.describe FormSubmission do
  describe "associations" do
    it { should belong_to(:person) }
    it { should belong_to(:form) }
    it { should have_many(:form_answers).dependent(:destroy) }
    it { should accept_nested_attributes_for(:form_answers) }
  end
end
