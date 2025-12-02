require 'rails_helper'

RSpec.describe "facilitators/show", type: :view do
  let(:admin) { create(:user, :admin) }

  let(:facilitator) { create(:facilitator)}

  before do
    assign(:facilitator, facilitator.decorate)
    allow(view).to receive(:current_user).and_return(admin)
    render
  end

  it "renders attributes" do
    expect(rendered).to match(facilitator.first_name)
    expect(rendered).to match(facilitator.last_name)
    expect(rendered).to match(facilitator.user.email)
  end
end
