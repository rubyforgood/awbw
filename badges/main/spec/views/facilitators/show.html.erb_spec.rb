require 'rails_helper'

RSpec.describe "facilitators/show", type: :view do
  let!(:combined_perm) { create(:permission, :combined) }
  let!(:adult_perm)    { create(:permission, :adult) }
  let!(:children_perm) { create(:permission, :children) }
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let(:facilitator) { create(:facilitator)}

  before do
    assign(:facilitator, facilitator.decorate)
    allow(view).to receive(:current_user).and_return(user)
    render
  end

  it "renders attributes in <p>" do
    expect(rendered).to match(facilitator.user.first_name)
    expect(rendered).to match(facilitator.user.last_name)
    expect(rendered).to match(facilitator.user.email)
  end
end
