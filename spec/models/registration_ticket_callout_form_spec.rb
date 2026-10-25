require "rails_helper"

RSpec.describe RegistrationTicketCalloutForm do
  let(:event) { create(:event) }
  let(:ce_callout) { create(:registration_ticket_callout, event:, builtin_key: "ce_hours") }

  def link(callout, form)
    callout.registration_ticket_callout_forms.build(form:)
  end

  describe "on the CE hours callout" do
    it "accepts an anonymous form that asks no name or email" do
      form = create(:form, anonymous: true)
      create(:form_field, form:, name: "How was it?")

      expect(link(ce_callout, form)).to be_valid
    end

    it "rejects a form without anonymous responses" do
      callout_form = link(ce_callout, create(:form, name: "CE eval"))

      expect(callout_form).not_to be_valid
      expect(callout_form.errors[:form]).to include("(CE eval) must have anonymous responses turned on")
    end

    Form::NAMING_IDENTIFIERS.each do |identifier|
      it "rejects an anonymous form that asks #{identifier}" do
        form = create(:form, name: "CE eval", anonymous: true)
        create(:form_field, form:, name: identifier.humanize, field_identifier: identifier, required: false)
        callout_form = link(ce_callout, form)

        expect(callout_form).not_to be_valid
        expect(callout_form.errors[:form]).to include("(CE eval) can't ask for a name or email")
      end
    end
  end

  it "accepts any form on another callout" do
    form = create(:form)
    create(:form_field, form:, name: "First name", field_identifier: "first_name")

    expect(link(create(:registration_ticket_callout, event:), form)).to be_valid
  end
end
