require "rails_helper"

RSpec.describe CloseProgramFormSeeder do
  it "creates the Close Program form with the close_program role and sections" do
    name = described_class.call

    expect(name).to eq("Close Program")
    form = Form.find_by(name: "Close Program")
    expect(form.role).to eq("close_program")
    identifiers = form.form_fields.pluck(:field_identifier)
    expect(identifiers).to include("first_name", "organization_name", "close_effective_date",
                                   "close_reason", "close_leaving_job")
  end

  it "is idempotent on form name" do
    described_class.call

    expect { described_class.call }.not_to change(Form, :count)
    expect(described_class.call).to be_nil
  end
end
