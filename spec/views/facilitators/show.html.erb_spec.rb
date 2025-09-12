require 'rails_helper'

RSpec.describe "facilitators/show", type: :view do
  let(:facilitator) { create(:facilitator)}

  before do
    assign(:facilitator, facilitator)
    render
  end

  it "renders attributes in <p>" do
    expect(rendered).to match(facilitator.first_name)
    expect(rendered).to match(facilitator.last_name)
    expect(rendered).to match(facilitator.email)
  end
end
