require "rails_helper"

RSpec.describe StaffTranslation do
  let(:user) { create(:user) }

  it "resolves a name to the user recorded for it, whatever its case or spacing" do
    create(:staff_alias, name: "Jamie Rivera", user:)

    expect(described_class.new.user_id_for("  jamie  RIVERA ")).to eq(user.id)
  end

  it "resolves several spellings recorded for one user" do
    create(:staff_alias, name: "Jamie Rivera", user:)
    create(:staff_alias, name: "Jamie", user:)

    translation = described_class.new
    expect([ translation.user_id_for("Jamie Rivera"), translation.user_id_for("jamie") ]).to eq([ user.id, user.id ])
  end

  it "counts a name nothing answers to, without guessing" do
    translation = described_class.new

    expect(translation.user_id_for("Office Laptop")).to be_nil
    translation.user_id_for("Office Laptop")
    expect(translation.unmatched).to eq("Office Laptop" => 2)
  end

  it "leaves a name recorded as ignored out of the unmatched count" do
    create(:staff_alias, :ignored, name: "Staff")

    translation = described_class.new
    expect(translation.user_id_for("staff")).to be_nil
    expect(translation.unmatched).to be_empty
  end

  it "answers nil for a blank value without counting it" do
    translation = described_class.new

    expect(translation.user_id_for(" ")).to be_nil
    expect(translation.unmatched).to be_empty
  end
end
