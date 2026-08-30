require "rails_helper"

RSpec.describe FormDecorator do
  include Rails.application.routes.url_helpers

  describe "#answers_path / #answers_label" do
    it "links a workshop-log template to the workshop logs index" do
      form = create(:form, owner: create(:form_builder, name: "Adult Workshop Log")).decorate
      expect(form.answers_path).to eq(workshop_logs_path)
      expect(form.answers_label).to eq("View workshop logs")
    end

    it "links a monthly-report template to its filtered monthly reports index" do
      builder = create(:form_builder, name: "Adult Monthly Report")
      form = create(:form, owner: builder).decorate
      expect(form.answers_path).to eq(monthly_reports_path(form_builder_id: builder.id))
      expect(form.answers_label).to eq("View monthly reports")
    end

    it "falls back to the form results rollup for a non-report owner" do
      form = create(:form, :with_owner).decorate
      expect(form.answers_path).to eq(results_form_path(form.object))
      expect(form.answers_label).to eq("View answers")
    end
  end

  describe "#owner_label" do
    it "labels a report-template owner" do
      form = create(:form, owner: create(:form_builder, name: "Adult Workshop Log")).decorate
      expect(form.owner_label).to eq("Report template · Adult Workshop Log")
    end

    it "labels a non-FormBuilder owner by its humanized type" do
      form = create(:form, :with_owner).decorate
      expect(form.owner_label).to start_with("User · ")
    end
  end
end
