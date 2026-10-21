require "rails_helper"

RSpec.describe FormsHelper, type: :helper do
  describe "#max_length_placeholder" do
    it "names the input and its limit" do
      expect(helper.max_length_placeholder("Question text", 1000)).to eq("Question text (1,000 char max)")
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

    it "links to the event public registration path when form is not publicly fillable" do
      form = create(:form, published: false)
      assign(:form, form)

      link = helper.form_live_view_link(event)
      expect(link).to include(new_event_public_registration_path(event))
      expect(link).to include("Live form")
    end

    it "returns nil when event is nil" do
      expect(helper.form_live_view_link(nil)).to be_nil
    end
  end
end
