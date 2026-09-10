# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonServices::ReconcileDefaultPayCustomer do
  let(:person) { create(:person) }

  def customer(processor_id:, default: true)
    Pay::Customer.create!(owner: person, processor: "fake", processor_id: processor_id, default: default)
  end

  it "demotes every default but the preferred one" do
    preferred = customer(processor_id: "cus_keep")
    other = customer(processor_id: "cus_other")

    described_class.new(person, preferred_customer_id: preferred.id).call

    expect(preferred.reload.default).to be true
    expect(other.reload.default).to be false
  end

  it "falls back to the newest default when the preferred id is absent" do
    older = customer(processor_id: "cus_old")
    older.update!(created_at: 2.days.ago)
    newer = customer(processor_id: "cus_new")

    described_class.new(person, preferred_customer_id: nil).call

    expect(newer.reload.default).to be true
    expect(older.reload.default).to be false
  end

  it "is a no-op when only one default customer exists" do
    only = customer(processor_id: "cus_only")

    expect { described_class.new(person, preferred_customer_id: nil).call }
      .not_to change { only.reload.default }
  end
end
