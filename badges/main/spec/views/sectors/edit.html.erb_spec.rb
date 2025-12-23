require "rails_helper"

RSpec.describe "sectors/edit", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:sector) { create(:sector) }

  before do
    assign(:sector, sector)
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders the edit sector form with metadatum select" do
    render

    assert_select "input[name=?]", "sector[name]"
    assert_select "input[name=?][type=checkbox]", "sector[published]"
  end
end
