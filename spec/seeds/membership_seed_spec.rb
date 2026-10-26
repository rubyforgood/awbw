require "rails_helper"

RSpec.describe "dev seed: membership" do
  let(:seed) { Rails.root.join("db/seeds/dev/membership.rb") }
  let(:volume_seed) { Rails.root.join("db/seeds/dev/membership_pagination.rb") }

  before { create(:user, :admin, email: "umberto.user@example.com") }

  def gapped_memberships
    Membership.includes(:membership_invoices).select do |membership|
      years = membership.membership_invoices.sort_by(&:start_date)
      years.each_cons(2).any? { |earlier, later| later.start_date != earlier.end_date + 1.day }
    end
  end

  it "gives every scenario back-to-back years" do
    load seed

    expect(gapped_memberships).to be_empty
  end

  it "never leaves a membership without an invoice" do
    load seed

    expect(Membership.includes(:membership_invoices).select { |membership| membership.membership_invoices.empty? })
      .to be_empty
  end

  it "reaches every directory state" do
    load seed

    expect(Membership.active.count).to be_positive
    expect(Membership.ending.count).to be_positive
    expect(Membership.lapsed.count).to be_positive
    expect(Membership.ended.count).to be_positive
  end

  it "stops renewals before a membership can end owing nothing" do
    load seed

    ended_without_cancellation = Membership.ended.reject(&:autorenewal_cancelled?)

    expect(ended_without_cancellation.map { |membership| membership.person.first_name }).to eq([ "Duplicate" ])
  end

  it "gives the autopay demos a real billing period and ends the cancelling one at the period boundary" do
    load seed

    subscriptions = Pay::Subscription.all.to_a
    expect(subscriptions.size).to eq(2)
    expect(subscriptions.map(&:current_period_start)).to all(be_present)
    expect(subscriptions.map(&:current_period_end)).to all(be_present)

    cancelling = subscriptions.find { |subscription| subscription.ends_at.present? }
    membership = Membership.find(cancelling.metadata["membership_id"])
    boundary = Time.use_zone(Membership::TIME_ZONE) do
      (membership.membership_invoices.sole.end_date + 1.day).beginning_of_day
    end

    expect(cancelling.ends_at).to eq(boundary)
  end

  it "dates invoices at mint time and payments at the start of the year they pay for" do
    load seed

    invoice = MembershipInvoice.joins(:allocations).order(:start_date).first

    expect(invoice.created_at).to be < invoice.start_date.in_time_zone
    expect(invoice.allocations.first.created_at.to_date).to be > invoice.start_date
  end

  it "skips a second run" do
    load seed

    expect { load seed }.not_to change(Membership, :count)
  end

  it "gives the pagination volume back-to-back years, 30 per directory state" do
    load volume_seed

    expect(gapped_memberships).to be_empty
    expect(%w[active ending lapsed ended].index_with { |state| Membership.public_send(state).count })
      .to eq("active" => 30, "ending" => 30, "lapsed" => 30, "ended" => 30)
  end
end
