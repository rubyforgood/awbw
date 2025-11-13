require 'rails_helper'

RSpec.describe "facilitators/index", type: :view do
  let!(:combined_perm) { create(:permission, :combined) }
  let!(:adult_perm)    { create(:permission, :adult) }
  let!(:children_perm) { create(:permission, :children) }
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let(:facilitator) { create(:facilitator)}
  let(:facilitator_2) { create(:facilitator)}

  before(:each) do
    assign(:facilitators, paginated([facilitator, facilitator_2]))
    allow(view).to receive(:current_user).and_return(user)
  end

  it "renders a list of facilitators" do
    render
    expect(rendered).to match(facilitator.user.first_name)
    expect(rendered).to match(facilitator_2.user.first_name)
  end
end
