# frozen_string_literal: true

require "rails_helper"

# Merging two people must consolidate their professional licenses without ever
# destroying a license that carries CE history. A license identified by the same
# (kind, number) collides on the unique index, so the merge collapses the two into
# one — but the losing license's CE registrations must move to the survivor, not
# cascade away (ProfessionalLicense refuses to destroy a license with CE regs).
RSpec.describe "People dedupe — professional licenses", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  def merge!(keep:, delete:)
    post dedupe_perform_people_path, params: {
      person_to_keep_id: keep.id,
      person_to_delete_id: delete.id
    }
  end

  # A license on `person` plus a CE registration hanging off it (at its own event).
  def license_with_ce(person, number:, kind: "LMFT")
    license = create(:professional_license, person: person, number: number, kind: kind)
    registration = create(:event_registration, registrant: person)
    create(:continuing_education_registration, event_registration: registration, professional_license: license)
    license
  end

  describe "colliding licenses that both carry CE (the reported failure)" do
    let!(:keep) { create(:person, first_name: "Jane", last_name: "Doe", email: "jane@real.test") }
    let!(:delete_rec) { create(:person, first_name: "Jane", last_name: "Doe", email: "jane2@real.test") }
    let!(:keep_license) { license_with_ce(keep, number: nil) }
    let!(:delete_license) { license_with_ce(delete_rec, number: nil) }

    it "merges successfully instead of erroring on the destroy" do
      merge!(keep: keep, delete: delete_rec)

      expect(response).to redirect_to(people_path)
      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(response.body).not_to include("Error merging")
    end

    it "leaves the keeper with a single license holding both CE registrations" do
      merge!(keep: keep, delete: delete_rec)

      expect(Person.exists?(delete_rec.id)).to be false
      expect(keep.reload.professional_licenses.count).to eq(1)

      survivor = keep.professional_licenses.first
      expect(survivor.continuing_education_registrations.count).to eq(2)
      expect(ContinuingEducationRegistration.count).to eq(2)
    end
  end

  describe "both licenses have an empty number (same kind)" do
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_license) { license_with_ce(keep, number: nil) }
    let!(:delete_license) { license_with_ce(delete_rec, number: nil) }

    it "ends up with just one license on the keeper" do
      merge!(keep: keep, delete: delete_rec)

      expect(keep.reload.professional_licenses.count).to eq(1)
      expect(keep.professional_licenses.first.continuing_education_registrations.count).to eq(2)
    end
  end

  describe "licenses with different numbers (same kind)" do
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_license) { license_with_ce(keep, number: "LIC-A") }
    let!(:delete_license) { license_with_ce(delete_rec, number: "LIC-B") }

    it "keeps both licenses on the keeper, each with its own CE" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.professional_licenses.order(:number).pluck(:number)).to eq(%w[LIC-A LIC-B])
      keep.professional_licenses.each do |license|
        expect(license.continuing_education_registrations.count).to eq(1)
      end
    end
  end

  describe "one license numbered, the other empty (same kind)" do
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_license) { license_with_ce(keep, number: "LIC-A") }
    let!(:delete_license) { license_with_ce(delete_rec, number: nil) }

    it "folds the empty placeholder into the numbered license, keeping its CE" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.professional_licenses.pluck(:number)).to eq([ "LIC-A" ])
      expect(keep.professional_licenses.first.continuing_education_registrations.count).to eq(2)
    end
  end

  describe 'one license blank as "" and the other nil (same kind)' do
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_license) { license_with_ce(keep, number: "") }
    let!(:delete_license) { license_with_ce(delete_rec, number: nil) }

    it "collapses the two empty licenses into one" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.professional_licenses.count).to eq(1)
      expect(keep.professional_licenses.first.continuing_education_registrations.count).to eq(2)
    end
  end

  describe "two real numbers plus an empty placeholder (same kind)" do
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_license) { license_with_ce(keep, number: "LIC-A") }
    let!(:numbered_b) { license_with_ce(delete_rec, number: "LIC-B") }
    let!(:placeholder) { license_with_ce(delete_rec, number: nil) }

    it "keeps both real numbers and folds the placeholder into one of them" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.professional_licenses.order(:number).pluck(:number)).to eq(%w[LIC-A LIC-B])
    end
  end

  describe "only the losing license carries CE (colliding placeholders)" do
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_license) { create(:professional_license, person: keep, number: nil, kind: "LMFT") }
    let!(:delete_license) { license_with_ce(delete_rec, number: nil) }

    it "moves the losing license's CE onto the surviving license" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.professional_licenses.count).to eq(1)
      expect(keep.professional_licenses.first.continuing_education_registrations.count).to eq(1)
    end
  end

  describe "duplicate CE registrations for the same event" do
    let!(:event) { create(:event) }
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_reg) { create(:event_registration, registrant: keep, event: event) }
    let!(:delete_reg) { create(:event_registration, registrant: delete_rec, event: event) }
    let!(:keep_license) { create(:professional_license, :placeholder, person: keep, kind: "LMFT") }
    let!(:delete_license) { create(:professional_license, :placeholder, person: delete_rec, kind: "LMFT") }
    let!(:keep_ce) { create(:continuing_education_registration, event_registration: keep_reg, professional_license: keep_license) }
    let!(:delete_ce) { create(:continuing_education_registration, event_registration: delete_reg, professional_license: delete_license) }
    let!(:payment) { create(:payment, person: delete_rec, amount_cents: 5_000, amount_cents_remaining: 0) }
    let!(:allocation) { create(:allocation, source: payment, allocatable: delete_ce, amount: 5_000) }

    it "collapses them into a single CE registration" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(ContinuingEducationRegistration.for_registrant(keep.id).count).to eq(1)
    end

    it "keeps the losing CE registration's payment on the survivor" do
      merge!(keep: keep, delete: delete_rec)

      survivor = ContinuingEducationRegistration.for_registrant(keep.id).first
      expect(Allocation.exists?(allocation.id)).to be true
      expect(survivor.allocations.pluck(:id)).to include(allocation.id)
      expect(survivor.allocations_sum).to eq(5_000)
    end
  end

  describe "CE registrations for different events" do
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_license) { license_with_ce(keep, number: nil) }
    let!(:delete_license) { license_with_ce(delete_rec, number: nil) }

    it "keeps both CE registrations (only same-event duplicates collapse)" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(ContinuingEducationRegistration.for_registrant(keep.id).count).to eq(2)
    end
  end

  describe "primary sector and age range designations" do
    let!(:age_type) { create(:category_type, :published, name: "AgeRange") }
    let!(:keep_sector) { create(:sector) }
    let!(:dupe_sector) { create(:sector) }
    let!(:keep_age) { create(:category, :published, category_type: age_type) }
    let!(:dupe_age) { create(:category, :published, category_type: age_type) }
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }

    before do
      create(:sectorable_item, sectorable: keep, sector: keep_sector, is_primary: true)
      create(:sectorable_item, sectorable: delete_rec, sector: dupe_sector, is_primary: true)
      create(:categorizable_item, categorizable: keep, category: keep_age, is_primary: true)
      create(:categorizable_item, categorizable: delete_rec, category: dupe_age, is_primary: true)
    end

    it "keeps only the survivor's primary sector" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      primaries = keep.reload.sectorable_items.where(is_primary: true)
      expect(primaries.count).to eq(1)
      expect(primaries.first.sector_id).to eq(keep_sector.id)
    end

    it "keeps only the survivor's primary age range" do
      merge!(keep: keep, delete: delete_rec)

      primaries = keep.reload.age_range_categorizable_items.where(is_primary: true)
      expect(primaries.count).to eq(1)
      expect(primaries.first.category_id).to eq(keep_age.id)
    end

    it "keeps both people's sectors and age ranges, just not both as primary" do
      merge!(keep: keep, delete: delete_rec)

      expect(keep.reload.sectorable_items.pluck(:sector_id)).to contain_exactly(keep_sector.id, dupe_sector.id)
      expect(keep.age_range_categorizable_items.pluck(:category_id)).to contain_exactly(keep_age.id, dupe_age.id)
    end

    it "succeeds even when the keeper is edited in the same request" do
      post dedupe_perform_people_path, params: {
        person_to_keep_id: keep.id,
        person_to_delete_id: delete_rec.id,
        person_to_keep: { first_name: "Renamed" }
      }

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.first_name).to eq("Renamed")
      expect(keep.sectorable_items.where(is_primary: true).count).to eq(1)
    end
  end

  describe "both people share the same primary sector and age range" do
    let!(:age_type) { create(:category_type, :published, name: "AgeRange") }
    let!(:sector) { create(:sector) }
    let!(:age) { create(:category, :published, category_type: age_type) }
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }

    before do
      create(:sectorable_item, sectorable: keep, sector: sector, is_primary: true)
      create(:sectorable_item, sectorable: delete_rec, sector: sector, is_primary: true)
      create(:categorizable_item, categorizable: keep, category: age, is_primary: true)
      create(:categorizable_item, categorizable: delete_rec, category: age, is_primary: true)
    end

    it "collapses to a single primary tagging, not one primary and one not" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      sectors = keep.reload.sectorable_items
      expect(sectors.count).to eq(1)
      expect(sectors.first).to be_is_primary
      ages = keep.age_range_categorizable_items
      expect(ages.count).to eq(1)
      expect(ages.first).to be_is_primary
    end
  end

  describe "only the deleted person has a primary sector" do
    let!(:age_type) { create(:category_type, :published, name: "AgeRange") }
    let!(:keep_sector) { create(:sector) }
    let!(:dupe_sector) { create(:sector) }
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }

    before do
      create(:sectorable_item, sectorable: keep, sector: keep_sector, is_primary: false)
      create(:sectorable_item, sectorable: delete_rec, sector: dupe_sector, is_primary: true)
    end

    it "keeps the deleted person's primary when the survivor had none" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      primaries = keep.reload.sectorable_items.where(is_primary: true)
      expect(primaries.count).to eq(1)
      expect(primaries.first.sector_id).to eq(dupe_sector.id)
    end
  end

  describe "consolidation keeps the real cost rather than inventing one" do
    let!(:event) { create(:event) }
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_reg) { create(:event_registration, registrant: keep, event: event) }
    let!(:delete_reg) { create(:event_registration, registrant: delete_rec, event: event) }
    let!(:keep_license) { create(:professional_license, :placeholder, person: keep, kind: "LMFT") }
    let!(:delete_license) { create(:professional_license, :placeholder, person: delete_rec, kind: "LMFT") }
    # Each record was legitimately paid in full on its own; folding them onto one
    # $5,000 enrollment leaves $10,000 allocated. The merge keeps the real $5,000
    # cost (not an invented $10,000) and flags the over-allocation for a human.
    let!(:keep_ce) { create(:continuing_education_registration, event_registration: keep_reg, professional_license: keep_license, cost_cents: 5_000) }
    let!(:delete_ce) { create(:continuing_education_registration, event_registration: delete_reg, professional_license: delete_license, cost_cents: 5_000) }
    let!(:keep_payment) { create(:allocation, source: create(:payment, person: keep, amount_cents: 5_000, amount_cents_remaining: 0), allocatable: keep_ce, amount: 5_000) }
    let!(:delete_payment) { create(:allocation, source: create(:payment, person: delete_rec, amount_cents: 5_000, amount_cents_remaining: 0), allocatable: delete_ce, amount: 5_000) }

    it "keeps the real cost intact and flags the survivor as over-allocated" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      survivors = ContinuingEducationRegistration.for_registrant(keep.id)
      expect(survivors.count).to eq(1)
      survivor = survivors.first
      expect(survivor.cost_cents).to eq(5_000)
      expect(survivor).to be_over_allocated
      expect(survivor.allocations_sum).to eq(10_000)
    end
  end

  describe "avatar" do
    def attach_avatar(person)
      blob = ActiveStorage::Blob.create_before_direct_upload!(
        filename: "face.png", byte_size: 1, checksum: "x", content_type: "image/png"
      )
      ActiveStorage::Attachment.create!(name: "avatar", record: person, blob: blob)
    end

    it "moves the deleted person's avatar to the keeper when the keeper has none" do
      keep = create(:person)
      delete_rec = create(:person)
      attachment = attach_avatar(delete_rec)

      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(attachment.reload.record_id).to eq(keep.id)
      expect(keep.reload.avatar).to be_attached
    end

    it "keeps the survivor's own avatar and drops the deleted person's" do
      keep = create(:person)
      delete_rec = create(:person)
      attach_avatar(keep)
      dupe_attachment = attach_avatar(delete_rec)

      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.avatar).to be_attached
      expect(ActiveStorage::Attachment.exists?(dupe_attachment.id)).to be false
    end
  end

  describe "billing (Pay) records" do
    def customer_with_charge(person, processor_id:, default: true)
      customer = Pay::Customer.create!(owner: person, processor: "fake", processor_id: processor_id, default: default)
      Pay::Charge.create!(customer: customer, amount: 5_000, processor_id: "ch_#{processor_id}",
                          object: { "paid" => false, "refunds" => { "data" => [] } })
      customer
    end

    it "reassigns the deleted person's Pay customer (and its charges) to the survivor" do
      keep = create(:person)
      delete_rec = create(:person)
      customer = customer_with_charge(delete_rec, processor_id: "cus_delete")

      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(customer.reload.owner_id).to eq(keep.id)
      expect(keep.reload.pay_customers).to include(customer)
      expect(keep.pay_charges.count).to eq(1)
    end

    it "keeps both people's Pay customers on the survivor when each had one" do
      keep = create(:person)
      delete_rec = create(:person)
      keep_customer = customer_with_charge(keep, processor_id: "cus_keep")
      delete_customer = customer_with_charge(delete_rec, processor_id: "cus_delete")

      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.pay_customers).to contain_exactly(keep_customer, delete_customer)
      expect(keep.pay_charges.count).to eq(2)
    end

    it "leaves the survivor with a single default customer (its own) when both were default" do
      keep = create(:person)
      delete_rec = create(:person)
      keep_customer = customer_with_charge(keep, processor_id: "cus_keep", default: true)
      delete_customer = customer_with_charge(delete_rec, processor_id: "cus_delete", default: true)

      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.pay_customers.active.where(default: true)).to contain_exactly(keep_customer)
      expect(delete_customer.reload.default).to be false
    end
  end

  describe "only the surviving license carries CE (losing placeholder is empty)" do
    let!(:keep) { create(:person) }
    let!(:delete_rec) { create(:person) }
    let!(:keep_license) { license_with_ce(keep, number: nil) }
    let!(:delete_license) { create(:professional_license, person: delete_rec, number: nil, kind: "LMFT") }

    it "discards the empty losing license and keeps the survivor's CE" do
      merge!(keep: keep, delete: delete_rec)

      follow_redirect!
      expect(response.body).to include("merged successfully")
      expect(keep.reload.professional_licenses.count).to eq(1)
      expect(keep.professional_licenses.first.continuing_education_registrations.count).to eq(1)
    end
  end
end
