require 'rails_helper'

RSpec.describe "faqs/index", type: :view do
  before(:each) do
    faq1 = Faq.create!(
      question: "Question",
      answer: "MyText",
      inactive: false,
      ordering: 2
    )
    faq2 = Faq.create!(
      question: "Question",
      answer: "MyText",
      inactive: false,
      ordering: 2
    )

    # Build a fake paginated collection
    faqs = WillPaginate::Collection.create(1, 2, 2) do |pager|
      pager.replace([faq1, faq2])
    end

    assign(:faqs, faqs)
  end

  it "renders a list of faqs" do
    render
    # headers
    assert_select "table thead th", text: "Question", count: 1
    assert_select "table thead th", text: "Answer",   count: 1

    # rows
    assert_select "table tbody tr", count: 2


    within "table tbody" do
      # faq1 spot check
      assert_select "tr>td", text: "What is Festi?", count: 1
      assert_select "tr>td", text: "An all-in-one platform", count: 1

      # faq2 spot check
      assert_select "table tbody td", text: "How do I sign up?", count: 1
      assert_select "table tbody td", text: "Click the signup button", count: 1
    end
  end
end
