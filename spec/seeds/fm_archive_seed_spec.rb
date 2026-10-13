require "rails_helper"

RSpec.describe "dev seed: fm_archive" do
  let(:seed) { Rails.root.join("db/seeds/dev/fm_archive.rb") }

  it "creates three rows in every FileMaker archive table" do
    load seed

    FmArchivesController::TABLES.each_value do |config|
      expect(config[:model].count).to eq(3), "expected 3 #{config[:model].name} rows"
    end
  end

  it "points the first two rows' links at seeded rows and the third's at missing ones" do
    load seed

    expect(FmRolodex.find_by!(fm_id: "00901").data["OrgID"]).to eq("ORG90001")
    expect(FmOrganization.exists?(fm_id: FmRolodex.find_by!(fm_id: "00902").data["OrgID"])).to be(true)
    expect(FmOrganization.exists?(fm_id: FmRolodex.find_by!(fm_id: "00903").data["OrgID"])).to be(false)
  end

  it "gives the alphabetically-first people a mix of matching and missing FileMaker codes" do
    zoe = create(:person, first_name: "Zoe")
    abe = create(:person, first_name: "Abe", last_name: "Archer")
    bea = create(:person, first_name: "Bea", last_name: "Baker")
    cal = create(:person, first_name: "Cal")

    load seed

    expect(abe.reload.filemaker_code).to eq("00901")
    expect(bea.reload.filemaker_code).to eq("00902, 00908")
    expect(cal.reload.filemaker_code).to eq("00999")
    expect(zoe.reload.filemaker_code).to be_nil
    expect(FmRolodex.find_by!(fm_id: "00901").data.values_at("FirstName", "LastName")).to eq(%w[Abe Archer])
  end

  it "gives Leader spotlights quotation codes ahead of other resources" do
    other = create(:resource, kind: "Toolkit", title: "Aaa toolkit")
    spotlight = create(:resource, kind: "LeaderSpotlight", title: "Zed spotlight")

    load seed

    expect(spotlight.reload.filemaker_code).to eq("Q90001")
    expect(other.reload.filemaker_code).to eq("Q90002, Q90008")
  end

  it "is idempotent" do
    load seed
    expect { load seed }.not_to change(FmPayment, :count)
  end
end
