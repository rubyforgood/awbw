require "rails_helper"

RSpec.describe PaymentDecorator, type: :decorator do
  describe "#page_title_label" do
    let(:view_context) { Draper::ViewContext.current.send(:view_context) }
    let(:person) { build_stubbed(:person, first_name: "Pat", last_name: "Example") }
    let(:organization) { build_stubbed(:organization, name: "Acme Shelter") }

    before { allow(view_context).to receive(:allowed_to?).with(:full_name?, anything).and_return(true) }

    it "names the person who paid" do
      payment = build_stubbed(:payment, payer_type: "Person", person: person, organization: organization)

      expect(payment.decorate.page_title_label).to eq("Payment · $10 · Pat Example")
    end

    it "names the organization that paid, not the person also on the payment" do
      payment = build_stubbed(:payment, payer_type: "Organization", person: person, organization: organization)

      expect(payment.decorate.page_title_label).to eq("Payment · $10 · Acme Shelter")
    end
  end
end
