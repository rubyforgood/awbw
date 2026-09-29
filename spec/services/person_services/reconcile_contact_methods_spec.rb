# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonServices::ReconcileContactMethods do
  let(:person) { create(:person) }

  def method(value: "555-1000", kind: "phone", primary: false)
    create(:contact_method, contactable: person, value: value, kind: kind, primary: primary)
  end

  it "folds identical contact methods into one" do
    keep = method
    dup = method

    described_class.new(person).call

    expect(person.contact_methods.reload.pluck(:id)).to eq([ keep.id ])
    expect(ContactMethod.exists?(dup.id)).to be false
  end

  it "keeps contact methods that differ in value or kind" do
    method(value: "555-1000")
    method(value: "555-2000")
    method(value: "555-1000", kind: "sms")

    described_class.new(person).call

    expect(person.contact_methods.reload.count).to eq(3)
  end

  it "keeps one primary per kind matching the given signatures and demotes the rest" do
    keep = method(value: "555-1000", primary: true)
    other = method(value: "555-2000", primary: true)

    described_class.new(person, primary_signatures: [ described_class.signature(keep) ]).call

    expect(keep.reload.primary?).to be true
    expect(other.reload.primary?).to be false
  end
end
