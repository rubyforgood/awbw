require 'rails_helper'

RSpec.describe "users/show", type: :view do
  let!(:combined_perm) { Permission.create!(security_cat: "Combined Adult and Children's Windows") }
  let!(:adult_perm)    { Permission.create!(security_cat: "Adult Windows") }
  let!(:children_perm) { Permission.create!(security_cat: "Children's Windows") }

  let(:user) do
    create(:user,
           first_name: "First Name",
           last_name: "Last Name",
           email: "Email@example.com",
           address: "Address",
           address2: "Address2",
           city: "City",
           city2: "City2",
           state: "State",
           state2: "State2",
           zip: "Zip",
           zip2: "Zip2",
           phone: "Phone",
           phone2: "Phone2",
           phone3: "Phone3",
           best_time_to_call: "Best Time To Call",
           comment: "MyText",
           notes: "MyText",
           inactive: false,
           super_user: false
    )
  end

  let(:super_user) { create(:user, :admin) }

  before do
    assign(:user, user)
    allow(view).to receive(:current_user).and_return(super_user)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/First Name/)
    expect(rendered).to match(/Last Name/)
    expect(rendered).to match(/email@example.com/) # it downcases emails
    expect(rendered).to match(/Address/)
    expect(rendered).to match(/Address2/)
    expect(rendered).to match(/City/)
    expect(rendered).to match(/City2/)
    expect(rendered).to match(/State/)
    expect(rendered).to match(/State2/)
    expect(rendered).to match(/Zip/)
    expect(rendered).to match(/Zip2/)
    expect(rendered).to match(/Phone/)
    expect(rendered).to match(/Phone2/)
    expect(rendered).to match(/Phone3/)
    expect(rendered).to match(/Best Time To Call/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/false/)
    expect(rendered).to match(/false/)
  end
end
