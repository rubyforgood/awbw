require 'rails_helper'

RSpec.describe "project_statuses/show", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:project_status) { create(:project_status, name: "Name") }

  before(:each) do
    assign(:project_status, project_status)
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
  end
end
