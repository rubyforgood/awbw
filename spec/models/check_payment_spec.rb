require "rails_helper"

RSpec.describe CheckPayment do
  let(:person) { create(:person) }

  def check(number)
    described_class.new(person:, amount_cents: 5_000, check_number: number)
  end

  it "accepts digits, optionally grouped by hyphens" do
    expect(check("1234")).to be_valid
    expect(check("53-0633995")).to be_valid
  end

  it "strips surrounding spaces" do
    payment = check(" 1234 ")
    payment.valid?
    expect(payment.check_number).to eq("1234")
  end

  it "rejects anything else" do
    [ "Check #1234", "#1234", "12 34", "1234-", "-1234", "12--34", "abc" ].each do |number|
      payment = check(number)
      expect(payment).not_to be_valid, "expected #{number.inspect} to be invalid"
      expect(payment.errors[:check_number]).to include("can only contain digits and hyphens (e.g. 53-0633995)")
    end
  end

  it "still saves an existing record whose number predates the rule" do
    payment = check("1234")
    payment.save!
    payment.update_column(:check_number, "Check #1234")

    expect(payment.reload.update(memo: "Spring workshop")).to be(true)
  end
end
