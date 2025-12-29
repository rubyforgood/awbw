RSpec.describe TagsHelper, type: :helper do
  let(:sector)   { create(:sector, name: "Veterans & Military") }
  let(:category) { create(:category, name: "Trauma") }

  it "builds sector tag links correctly" do
    expect(
      helper.tag_link_for(Workshop, tag: sector, type: :sector)
    ).to eq("/workshops?sector_names=Veterans+%26+Military")
  end

  it "builds category tag links correctly" do
    expect(
      helper.tag_link_for(Workshop, tag: category, type: :category)
    ).to eq("/workshops?category_names=Trauma")
  end
end
