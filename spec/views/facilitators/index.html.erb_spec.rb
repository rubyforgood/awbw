require 'rails_helper'

RSpec.describe "facilitators/index", type: :view do
  let(:facilitator) { create(:facilitator)}
  let(:facilitator_2) { create(:facilitator)}

  before do
    assign(:facilitators, [facilitator, facilitator_2])
    render
  end

  it "renders a list of facilitators" do
    expect(rendered).to match(facilitator.email)
    expect(rendered).to match(facilitator_2.email)
  end
end
