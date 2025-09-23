require 'rails_helper'

RSpec.describe "faqs/edit", type: :view do
  let(:faq) {
    Faq.create!(
      question: "MyString",
      answer: "MyText",
      inactive: false,
      ordering: 1
    )
  }

  before(:each) do
    assign(:faq, faq)
    allow(view).to receive(:current_user).and_return(build(:user, super_user: true))
  end

  it "renders the edit faq form" do
    render

    assert_select "form[action=?][method=?]", faq_path(faq), "post" do

      assert_select "input[name=?]", "faq[question]"

      assert_select "textarea[name=?]", "faq[answer]"

      assert_select "input[name=?]", "faq[inactive]"

      assert_select "input[name=?]", "faq[ordering]"
    end
  end
end
