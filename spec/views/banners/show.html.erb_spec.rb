require 'rails_helper'

RSpec.describe "banners/show", type: :view do
  let!(:combined_perm) { create(:permission, :combined) }
  let!(:adult_perm)    { create(:permission, :adult) }
  let!(:children_perm) { create(:permission, :children) }
  let(:admin) { create(:user, :admin) }

  before(:each) do
    assign(:banner, Banner.create!(
      content: "MyText",
      show: false,
      created_by: admin,
      updated_by: admin
    ))
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/false/)
    expect(rendered).to match(//)
    expect(rendered).to match(//)
  end
end
