require "rails_helper"

RSpec.describe EventForm, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:event) }
    it { is_expected.to belong_to(:form) }
  end

  describe "validations" do
    subject { build(:event_form) }

    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_inclusion_of(:role).in_array(EventForm::ROLES) }

    it "validates uniqueness of form_id scoped to event_id and role" do
      event_form = create(:event_form)
      duplicate = build(:event_form, event: event_form.event, form: event_form.form, role: event_form.role)
      expect(duplicate).not_to be_valid
    end

    it "allows the same form on different events" do
      form = create(:form)
      create(:event_form, form: form, role: "registration")
      other = build(:event_form, form: form, role: "registration")
      expect(other).to be_valid
    end

    it "allows different roles for the same event and form" do
      event_form = create(:event_form, role: "registration")
      other = build(:event_form, event: event_form.event, form: event_form.form, role: "scholarship")
      expect(other).to be_valid
    end
  end

  describe "scopes" do
    let!(:registration) { create(:event_form, role: "registration") }
    let!(:scholarship) { create(:event_form, role: "scholarship") }

    it ".registration returns only registration records" do
      expect(EventForm.registration).to contain_exactly(registration)
    end

    it ".scholarship returns only scholarship records" do
      expect(EventForm.scholarship).to contain_exactly(scholarship)
    end
  end
end
