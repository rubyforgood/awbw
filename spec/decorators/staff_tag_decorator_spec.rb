require "rails_helper"

RSpec.describe StaffTagDecorator do
  it "titles with the name" do
    tag = create(:staff_tag, name: "Highlight roster").decorate
    expect(tag.title).to eq("Highlight roster")
  end

  it "details with the description" do
    tag = create(:staff_tag, description: "Pipeline note").decorate
    expect(tag.detail).to eq("Pipeline note")
  end

  it "labels active and archived status" do
    expect(create(:staff_tag).decorate.status_label).to eq("Active")
    expect(create(:staff_tag, :archived).decorate.status_label).to eq("Archived")
  end
end
