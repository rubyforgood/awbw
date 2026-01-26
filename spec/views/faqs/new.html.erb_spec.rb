require 'rails_helper'

RSpec.describe "faqs/new", type: :view do
  before(:each) do
    assign(:faq, Faq.new(
      question: "MyString",
      answer: "MyText",
      inactive: false,
      position: 1
    ))
  end

  it "renders new faq form" do
    render

    assert_select "form[action=?][method=?]", faqs_path, "post" do
      assert_select "input[name=?]", "faq[question]"

      assert_select "textarea[name=?]", "faq[answer]"

      assert_select "input[name=?]", "faq[inactive]"

      assert_select "input[name=?]", "faq[position]"
    end
  end
end
