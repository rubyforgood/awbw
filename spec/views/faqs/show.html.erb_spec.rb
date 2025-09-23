require 'rails_helper'

RSpec.describe "faqs/show", type: :view do
  before(:each) do
    assign(:faq, Faq.create!(
      question: "Question",
      answer: "MyText",
      inactive: false,
      ordering: 2
    ))
  end

  before(:each) do
    allow(view).to receive(:current_user).and_return(build(:user, super_user: true))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Question/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/false/)
    expect(rendered).to match(/2/)
  end
end
