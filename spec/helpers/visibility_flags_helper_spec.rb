require "rails_helper"

RSpec.describe VisibilityFlagsHelper, type: :helper do
  describe "#visibility_flag_input" do
    let(:form) { instance_double(SimpleForm::FormBuilder) }

    it "renders the boolean input with the flag's definition as a hover title" do
      expect(form).to receive(:input).with(
        :published,
        as: :boolean,
        wrapper_html: { title: described_class::FLAG_DEFINITIONS[:published][:description] }
      )

      helper.visibility_flag_input(form, :published)
    end

    it "keeps a caller-supplied title and passes through other options" do
      expect(form).to receive(:input).with(
        :published,
        as: :boolean,
        wrapper_html: { title: "custom" },
        label: "Live?"
      )

      helper.visibility_flag_input(form, :published, wrapper_html: { title: "custom" }, label: "Live?")
    end
  end
end
