require "rails_helper"

RSpec.describe VisibilityFlagsHelper, type: :helper do
  describe "#visibility_flag_input" do
    let(:form) { instance_double(SimpleForm::FormBuilder) }

    it "renders the boolean input with the flag's hint and hover title" do
      definition = described_class::FLAG_DEFINITIONS[:published]

      expect(form).to receive(:input).with(
        :published,
        as: :boolean,
        wrapper_html: { title: definition[:description] },
        hint: definition[:hint]
      )

      helper.visibility_flag_input(form, :published)
    end

    it "uses definition_key to look up copy for a repurposed flag" do
      definition = described_class::FLAG_DEFINITIONS[:category_type_published]

      expect(form).to receive(:input).with(
        :published,
        as: :boolean,
        wrapper_html: { title: definition[:description] },
        hint: definition[:hint]
      )

      helper.visibility_flag_input(form, :published, definition_key: :category_type_published)
    end

    it "keeps a caller-supplied title and hint and passes through other options" do
      expect(form).to receive(:input).with(
        :published,
        as: :boolean,
        wrapper_html: { title: "custom" },
        hint: "my hint",
        label: "Live?"
      )

      helper.visibility_flag_input(form, :published, wrapper_html: { title: "custom" }, hint: "my hint", label: "Live?")
    end
  end
end
