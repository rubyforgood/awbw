# frozen_string_literal: true

require "rails_helper"

# Merging two duplicate registrations for the same event (always different Person
# records — the unique index guarantees it) moves the deleted registration's CE
# registration onto the keeper. But that CE still points at the deleted registrant's
# license, so it lands invalid (license belongs to the other person) and duplicates
# the keeper's own CE for the same enrollment. The merge must repoint it to the kept
# registrant's equivalent license and fold the duplicates into one, keeping payments.
RSpec.describe "Event registration dedupe — continuing education", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event) }
  let(:keep_person) { create(:person) }
  let(:delete_person) { create(:person) }
  let!(:keep_reg) { create(:event_registration, registrant: keep_person, event: event) }
  let!(:delete_reg) { create(:event_registration, registrant: delete_person, event: event) }
  let!(:keep_license) { create(:professional_license, person: keep_person, number: "123", kind: "LMFT") }
  let!(:delete_license) { create(:professional_license, person: delete_person, number: "123", kind: "LMFT") }
  let!(:keep_ce) { create(:continuing_education_registration, event_registration: keep_reg, professional_license: keep_license) }
  let!(:delete_ce) { create(:continuing_education_registration, event_registration: delete_reg, professional_license: delete_license) }
  let!(:payment) { create(:payment, person: delete_person, amount_cents: 5_000, amount_cents_remaining: 0) }
  let!(:allocation) { create(:allocation, source: payment, allocatable: delete_ce, amount: 5_000) }

  before { sign_in admin }

  def merge!
    post dedupe_perform_event_registrations_path, params: {
      event_registration_to_keep_id: keep_reg.id,
      event_registration_to_delete_id: delete_reg.id
    }
  end

  it "leaves the keeper with a single valid CE registration" do
    merge!

    expect(response).to redirect_to(event_registrations_path)
    ce_records = keep_reg.reload.continuing_education_registrations
    expect(ce_records.count).to eq(1)
    survivor = ce_records.first
    expect(survivor).to be_valid
    expect(survivor.professional_license.person_id).to eq(keep_person.id)
  end

  it "keeps the moved registration's payment on the surviving CE registration" do
    merge!

    survivor = keep_reg.reload.continuing_education_registrations.first
    expect(Allocation.exists?(allocation.id)).to be true
    expect(survivor.allocations.pluck(:id)).to include(allocation.id)
    expect(survivor.allocations_sum).to eq(5_000)
  end

  # A legacy placeholder license can store an empty string where another stores
  # nil. Both are "no number on file", so the repoint must land on the kept
  # registrant's existing placeholder rather than spawning a third license that
  # leaves the enrollment split across two CE records.
  context "when both registrants hold a blank-number placeholder license" do
    let!(:keep_license) { create(:professional_license, person: keep_person, number: "", kind: "LMFT") }
    let!(:delete_license) { create(:professional_license, person: delete_person, number: nil, kind: "LMFT") }

    it "collapses onto the keeper's existing placeholder license" do
      merge!

      ce_records = keep_reg.reload.continuing_education_registrations
      expect(ce_records.count).to eq(1)
      expect(ce_records.first.professional_license_id).to eq(keep_license.id)
      expect(keep_person.reload.professional_licenses.count).to eq(1)
    end
  end
end
