require "rails_helper"

RSpec.describe "db/seeds/dev/transfers.rb" do
  def load_seed
    load Rails.root.join("db/seeds/dev/transfers.rb")
  end

  def incoming_for(first_name)
    EventRegistration.transferred_in.joins(:registrant).find_by(people: { first_name: first_name })
  end

  before { allow($stdout).to receive(:puts) }

  it "seeds each transfer's balance across both registrations" do
    load_seed

    expect(incoming_for("Splitpaid")).to be_paid_in_full
    expect(incoming_for("Intends").remaining_cost).to eq(45_000)
    expect(incoming_for("Partial").remaining_cost).to eq(30_000)
  end

  it "is re-runnable without duplicating registrations or money" do
    load_seed

    expect { load_seed }.not_to change { [ EventRegistration.count, Allocation.count ] }
  end
end
