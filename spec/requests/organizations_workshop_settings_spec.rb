require "rails_helper"

RSpec.describe "Organization workshop settings picker", type: :request do
  let(:category_type) { create(:category_type, :published, profile_specific: true) }
  let!(:chosen) { create(:category, :published, category_type: category_type) }
  let!(:unchosen) { create(:category, :published, category_type: category_type) }
  let(:organization) { create(:organization) }

  before do
    create(:categorizable_item, categorizable: organization, category: chosen)
    sign_in create(:user, :admin)
  end

  def option_for(category)
    Nokogiri::HTML(response.body).at_css("#organization_category_ids_type_#{category_type.id} option[value='#{category.id}']")
  end

  it "preselects only the organization's settings" do
    get edit_organization_path(organization)

    expect(option_for(chosen)["selected"]).to eq("selected")
    expect(option_for(unchosen)["selected"]).to be_nil
  end

  it "clears every setting when the picker is emptied" do
    patch organization_path(organization), params: { organization: { name: organization.name, category_ids: [ "" ] } }

    expect(organization.reload.categories).to be_empty
  end
end
