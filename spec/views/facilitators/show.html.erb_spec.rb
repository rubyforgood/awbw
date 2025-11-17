require 'rails_helper'

RSpec.describe "facilitators/show", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let(:facilitator) { create(:facilitator)}

  before do
    assign(:facilitator, facilitator.decorate)
    allow(view).to receive(:current_user).and_return(user)
    render
  end

  it "renders attributes" do
    expect(rendered).to match(facilitator.user.first_name)
    expect(rendered).to match(facilitator.user.last_name)
    expect(rendered).to match(facilitator.user.email)
  end
end
