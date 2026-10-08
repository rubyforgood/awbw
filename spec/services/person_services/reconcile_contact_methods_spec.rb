# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonServices::ReconcileContactMethods do
  let(:person) { create(:person) }

  def contact_method(value: "555-1000", kind: "phone", **overrides)
    create(:contact_method, contactable: person, value: value, kind: kind, **overrides)
  end

  def address
    create(:address, addressable: person, street_address: "1 Main St", city: "Springfield",
                     state: "CA", zip_code: "90001", locality: "LA City")
  end

  it "folds identical contact methods into one" do
    keep = contact_method
    dup = contact_method

    described_class.new(person).call

    expect(person.contact_methods.reload.pluck(:id)).to eq([ keep.id ])
    expect(ContactMethod.exists?(dup.id)).to be false
  end

  it "keeps contact methods that differ in value or kind" do
    contact_method(value: "555-1000")
    contact_method(value: "555-2000")
    contact_method(value: "555-1000", kind: "sms")

    described_class.new(person).call

    expect(person.contact_methods.reload.count).to eq(3)
  end

  it "keeps one primary per kind matching the given signatures and demotes the rest" do
    keep = contact_method(value: "555-1000", primary: true)
    other = contact_method(value: "555-2000", primary: true)

    described_class.new(person, primary_signatures: [ described_class.signature(keep) ]).call

    expect(keep.reload.primary?).to be true
    expect(other.reload.primary?).to be false
  end

  it "folds into the active copy when an older duplicate is inactive" do
    inactive = contact_method(inactive: true)
    active = contact_method

    described_class.new(person).call

    expect(person.contact_methods.reload.pluck(:id)).to eq([ active.id ])
    expect(person.reload.phone_number).to eq("555-1000")
    expect(ContactMethod.exists?(inactive.id)).to be false
  end

  it "folds into the primary copy when the duplicate is not primary" do
    plain = contact_method
    primary = contact_method(primary: true)

    described_class.new(person, primary_signatures: [ described_class.signature(primary) ]).call

    expect(person.contact_methods.reload.pluck(:id)).to eq([ primary.id ])
    expect(ContactMethod.exists?(plain.id)).to be false
  end

  it "carries a folded contact method's address onto a survivor that has none" do
    keep = contact_method
    contact_method(address: address)

    described_class.new(person).call

    expect(keep.reload.address_id).to eq(Address.last.id)
  end

  it "leaves the survivor's own address alone when the duplicate also has one" do
    kept_address = address
    keep = contact_method(address: kept_address)
    contact_method(address: address)

    described_class.new(person).call

    expect(keep.reload.address_id).to eq(kept_address.id)
  end
end
