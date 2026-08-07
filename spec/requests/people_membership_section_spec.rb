require "rails_helper"

RSpec.describe "Person profile membership section", type: :request do
  around { |example| travel_to(Time.current.midday) { example.run } }

  let(:standard_cost) { MoneyFormatter.dollars_from_cents(Membership::ANNUAL_COST_CENTS) }
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  def membership_invoice_for(cost_cents: Membership::ANNUAL_COST_CENTS, start_date: Date.current, subscription: nil)
    create(:membership_invoice,
      membership: subscription || create(:membership, person: person),
      cost_cents: cost_cents,
      start_date: start_date,
      end_date: start_date + 1.year - 1.day)
  end

  context "as an admin" do
    before { sign_in admin }

    it "lists the person's invoices with cost and status" do
      membership_invoice_for

      get person_path(person)

      expect(response).to be_successful
      expect(response.body).to include("Membership")
      expect(response.body).to include(standard_cost)
      expect(response.body).to include("due")
    end

    it "shows the standard cost when the subscription has no override" do
      membership_invoice_for

      get person_path(person)

      expect(response.body).to include("Standard (#{standard_cost})")
    end

    it "shows a locked cost when the subscription has one" do
      subscription = create(:membership, person: person, cost_cents: 1_500)
      membership_invoice_for(subscription: subscription)

      get person_path(person)

      expect(response.body).to include("Locked at $15")
    end

    # Requests render in the viewer's zone (ApplicationController#set_time_zone_from_user,
    # defaulting to Pacific), so midday avoids the date shifting either side of midnight.
    it "shows when the subscription was cancelled" do
      subscription = create(:membership, person: person,
        cancelled_at: Time.zone.parse("2026-08-03 12:00"))
      membership_invoice_for(subscription: subscription)

      get person_path(person)

      expect(response.body).to include("Cancelled Aug 3, 2026")
    end

    it "shows only the year covering today, not the whole history" do
      subscription = create(:membership, person: person)
      older = membership_invoice_for(cost_cents: 0, start_date: Date.current - 1.year, subscription: subscription)
      current = membership_invoice_for(subscription: subscription)

      get person_path(person)

      expect(response.body).to include(current.decorate.period_range)
      expect(response.body).not_to include(older.decorate.period_range)
    end

    it "prefers the year covering today over a future one the job created early" do
      subscription = create(:membership, person: person)
      current = membership_invoice_for(subscription: subscription)
      future = membership_invoice_for(start_date: current.end_date + 1.day, subscription: subscription)

      get person_path(person)

      expect(response.body).to include(current.decorate.period_range)
      expect(response.body).not_to include(future.decorate.period_range)
    end

    it "links to the management page" do
      get person_path(person)

      expect(response.body).to include(person_memberships_path(person))
      expect(response.body).to include("Manage membership")
    end

    it "says so when the person has no subscription" do
      get person_path(person)

      expect(response.body).to include("No membership yet")
    end
  end

  context "as the person themselves" do
    before { sign_in owner_user }

    it "shows their current membership invoice" do
      year = membership_invoice_for

      get person_path(person)

      expect(response).to be_successful
      expect(response.body).to include("Annual membership")
      expect(response.body).to include(year.decorate.period_range)
    end

    it "offers the option to set up an annual membership" do
      membership_invoice_for

      get person_path(person)

      expect(response.body).to include("Set up annual membership")
      expect(response.body).to include(membership_checkouts_path)
    end

    it "opts the button out of Turbo, which cannot follow the redirect to Stripe" do
      get person_path(person)

      button = Nokogiri::HTML(response.body)
        .at_css("form[action='#{membership_checkouts_path}'] button[type=submit]")
      expect(button["data-turbo"]).to eq("false")
    end

    it "offers the option even with no subscription at all" do
      get person_path(person)

      expect(response).to be_successful
      expect(response.body).to include("Set up annual membership")
      expect(response.body).to include(membership_checkouts_path)
    end

    it "shows the standard cost when they have no rate of their own" do
      get person_path(person)

      expect(response.body).to include(standard_cost)
    end

    it "does not show the admin card or its management link" do
      membership_invoice_for

      get person_path(person)

      expect(response.body).not_to include("Manage membership")
      expect(response.body).not_to include("Standard (#{standard_cost})")
    end

    it "does not link the status pill to the admin allocations page" do
      year = membership_invoice_for

      get person_path(person)

      expect(response.body).not_to include(allocations_path(allocatable_sgid: year.to_sgid.to_s))
    end

    it "creates their Stripe customer record, ready for checkout" do
      expect { get person_path(person) }.to change { person.pay_customers.count }.by(1)

      customer = person.pay_customers.sole
      expect(customer).to have_attributes(processor: "stripe", default: true, processor_id: nil)
    end

    it "reuses that customer on later views" do
      get person_path(person)

      expect { get person_path(person) }.not_to change { person.pay_customers.count }
    end

    it "reports autopay instead of the button once a Stripe subscription is active" do
      membership_invoice_for
      customer = Pay::Customer.create!(owner: person, processor: "stripe", processor_id: "cus_test", default: true)
      Pay::Subscription.create!(customer: customer, name: "default", processor_id: "sub_test",
        processor_plan: "membership", status: "active", quantity: 1)

      get person_path(person)

      expect(response.body).to include("renews automatically")
      expect(response.body).not_to include("Set up annual membership")
    end
  end

  it "does not create a Stripe customer for someone else whose profile an admin views" do
    sign_in admin

    expect { get person_path(person) }.not_to change { person.pay_customers.count }
  end

  it "is unreachable for another signed-in user, who cannot view the profile at all" do
    membership_invoice_for
    sign_in create(:user, :with_person)

    get person_path(person)

    expect(response).to redirect_to(root_path)
  end

  it "stays hidden entirely while membership is disabled" do
    membership_invoice_for
    allow(Membership).to receive(:enabled?).and_return(false)
    sign_in owner_user

    get person_path(person)

    expect(response).to be_successful
    expect(response.body).not_to include("Standard (#{standard_cost})")
  end
end
