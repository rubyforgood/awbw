# frozen_string_literal: true

require "rails_helper"

RSpec.describe AffiliationDeduper do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }

  def affiliation(**attrs)
    create(:affiliation, person: person, organization: organization, title: "Facilitator", **attrs)
  end

  # A merge moves rows with update_all, so identical copies land without
  # Affiliation#skip_if_duplicate ever running; save without validation to match.
  def copy_of(original, **attrs)
    original.dup.tap do |copy|
      copy.assign_attributes(attrs)
      copy.save!(validate: false)
    end
  end

  it "merges identical affiliations into the oldest" do
    keep = affiliation
    copy_of(keep)
    copy_of(keep)

    described_class.new(person).call

    expect(person.affiliations.reload.pluck(:id)).to eq([ keep.id ])
  end

  it "keeps the copy linked to a registration" do
    original = affiliation
    registration = create(:event_registration, registrant: person)
    linked = copy_of(original, event_registration: registration)

    described_class.new(person).call

    expect(person.affiliations.reload.pluck(:id)).to eq([ linked.id ])
  end

  it "carries the primary contact flag, organization address, and FileMaker codes from the merged copies" do
    address = create(:address, addressable: organization)
    keep = affiliation(filemaker_code: "A1")
    copy_of(keep, primary_contact: true, organization_address_id: address.id, filemaker_code: "B2")

    described_class.new(person).call

    keep.reload
    expect(keep.primary_contact).to be true
    expect(keep.organization_address_id).to eq(address.id)
    expect(keep.filemaker_code).to eq("A1, B2")
  end

  it "moves the merged copies' comments onto the survivor" do
    keep = affiliation
    dup = copy_of(keep)
    comment = create(:comment, commentable: dup)

    described_class.new(person).call

    expect(comment.reload.commentable).to eq(keep)
  end

  it "keeps affiliations that differ in title, dates, or status" do
    keep = affiliation
    copy_of(keep, title: "Coordinator")
    copy_of(keep, start_date: Date.new(2025, 1, 1))
    copy_of(keep, inactive: true)

    described_class.new(person).call

    expect(person.affiliations.reload.count).to eq(4)
  end

  it "merges an organization's identical affiliations" do
    keep = affiliation
    copy_of(keep)

    described_class.new(organization).call

    expect(organization.affiliations.reload.pluck(:id)).to eq([ keep.id ])
  end
end
