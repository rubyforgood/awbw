# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonServices::KeepMergedEmails do
  let(:keep) { create(:person, email: "keeper@example.com", email_2: nil, user: nil) }
  let(:merged) { build(:person, first_name: "Merged", last_name: "Twin", email: "merged@example.com", email_type: "personal", email_2: nil) }

  def call = described_class.new(keep, merged: merged).call

  it "fills an empty email 2 with the merged person's email and its type" do
    call

    expect(keep.email_2).to eq("merged@example.com")
    expect(keep.email_2_type).to eq("personal")
  end

  it "leaves the keeper alone when it already holds the email, ignoring case" do
    keep.email_2 = "MERGED@example.com"

    expect { call }.not_to change { keep.comments.count }
    expect(keep.email_2).to eq("MERGED@example.com")
  end

  it "notes emails that don't fit in email 2 in a comment" do
    keep.email_2 = "keeper.alt@example.com"
    merged.email_2 = "merged.alt@example.com"

    call

    expect(keep.email_2).to eq("keeper.alt@example.com")
    expect(keep.comments.sole.body).to include("merged@example.com and merged.alt@example.com", "Merged Twin")
  end

  it "skips placeholder emails" do
    merged.email = PlaceholderEmail.first

    expect(described_class.new(keep, merged: merged).missing).to be_empty
  end
end
