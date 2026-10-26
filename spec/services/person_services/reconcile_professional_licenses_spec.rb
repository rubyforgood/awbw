# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonServices::ReconcileProfessionalLicenses do
  let(:person) { create(:person) }

  def license(number:, kind: "LMFT")
    create(:professional_license, person: person, number: number, kind: kind)
  end

  it "merges an empty placeholder into the real license of the same kind" do
    real = license(number: "LIC-A")
    placeholder = license(number: nil)

    described_class.new(person).call

    expect(person.professional_licenses.reload.pluck(:number)).to eq([ "LIC-A" ])
    expect(ProfessionalLicense.exists?(placeholder.id)).to be false
    expect(ProfessionalLicense.exists?(real.id)).to be true
  end

  it "collapses two blank licenses (nil and empty string) into one" do
    license(number: "")
    license(number: nil)

    described_class.new(person).call

    expect(person.professional_licenses.reload.count).to eq(1)
  end

  it "keeps two different real numbers of the same kind" do
    license(number: "LIC-A")
    license(number: "LIC-B")

    described_class.new(person).call

    expect(person.professional_licenses.reload.pluck(:number)).to contain_exactly("LIC-A", "LIC-B")
  end

  it "keeps a shared number across different kinds" do
    license(number: "SHARED", kind: "LMFT")
    license(number: "SHARED", kind: "LCSW")

    described_class.new(person).call

    expect(person.professional_licenses.reload.pluck(:kind)).to contain_exactly("LMFT", "LCSW")
  end

  it "folds a placeholder with no type into the person's only real license" do
    real = license(number: "LIC-A")
    placeholder = license(number: nil, kind: nil)

    described_class.new(person).call

    expect(person.professional_licenses.reload.pluck(:id)).to eq([ real.id ])
    expect(ProfessionalLicense.exists?(placeholder.id)).to be false
  end

  it "keeps a placeholder with no type when the person holds more than one real license" do
    license(number: "LIC-A")
    license(number: "LIC-B", kind: "LCSW")
    license(number: nil, kind: nil)

    described_class.new(person).call

    expect(person.professional_licenses.reload.count).to eq(3)
  end

  it "splits a license type typed into the number of an existing license" do
    typed = license(number: nil, kind: nil)
    typed.update_columns(number: "LMFT 42111")

    described_class.new(person).call

    expect(typed.reload).to have_attributes(kind: "LMFT", number: "42111")
  end

  it "merges a typed-in license into the matching license it duplicates" do
    real = license(number: "42111", kind: "LMFT")
    typed = license(number: nil, kind: nil)
    typed.update_columns(number: "LMFT 42111")

    described_class.new(person).call

    expect(person.professional_licenses.reload.pluck(:id)).to eq([ real.id ])
  end

  it "moves the placeholder's CE registrations onto the survivor" do
    real = license(number: "LIC-A")
    placeholder = license(number: nil)
    create(:continuing_education_registration,
      event_registration: create(:event_registration, registrant: person), professional_license: placeholder)

    described_class.new(person).call

    expect(real.reload.continuing_education_registrations.count).to eq(1)
  end
end
