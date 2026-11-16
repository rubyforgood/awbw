require "rails_helper"

RSpec.describe FormsHelper, type: :helper do
  describe "#max_length_placeholder" do
    it "names the input and its limit" do
      expect(helper.max_length_placeholder("Question text", 1000)).to eq("Question text (1,000 char max)")
    end
  end

  describe "#form_role_label" do
    it "uses the role's dropdown label" do
      expect(helper.form_role_label(build(:form, role: "continuing_education"))).to eq("Continuing education application")
    end

    it "falls back to General when no role is set" do
      expect(helper.form_role_label(build(:form, role: nil))).to eq("General")
    end
  end

  describe "#form_role_options" do
    it "separates the role groups with a rule and marks the selected role" do
      html = helper.form_role_options("scholarship")
      expect(html.scan("<hr>").size).to eq(Form::ROLE_GROUPS.size - 1)
      expect(html).to include('<option selected="selected" value="scholarship">Scholarship application</option>')
    end
  end

  describe "#form_live_view_link" do
    let(:event) { create(:event) }

    it "links to the public form path with event parameter for publicly fillable forms" do
      form = create(:form, slug: "day-1", published: true, role: "day_1_survey")
      assign(:form, form)

      link = helper.form_live_view_link(event)
      expect(link).to include(public_form_path(form.slug, event: event.id))
      expect(link).to include("Live form")
    end

    it "links to the event public registration path for a form connected to that event" do
      form = create(:form, published: false)
      create(:event_form, form: form, event: event)
      assign(:form, form)

      link = helper.form_live_view_link(event)
      expect(link).to include(new_event_public_registration_path(event))
      expect(link).to include("Live form")
    end

    # A survey form reaches the editor with an event it is only allowed for, so
    # that event's registration page is not this form's live page.
    it "returns nil for a form neither publicly fillable nor connected to the event" do
      assign(:form, create(:form, role: "day_1_survey", published: false))

      expect(helper.form_live_view_link(event)).to be_nil
    end

    it "returns nil when event is nil" do
      expect(helper.form_live_view_link(nil)).to be_nil
    end
  end
end
