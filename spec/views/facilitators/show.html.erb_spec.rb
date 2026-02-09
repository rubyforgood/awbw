require 'rails_helper'

RSpec.describe "people/show", type: :view do
  let(:admin) { create(:user, :admin) }

  let(:person) { create(:person) }

  before do
    assign(:person, person.decorate)
    allow(view).to receive(:current_user).and_return(admin)
    render
  end

  it "renders attributes" do
    expect(rendered).to match(person.first_name)
    expect(rendered).to match(person.last_name)
    expect(rendered).to match(person.user.email)
  end
end
