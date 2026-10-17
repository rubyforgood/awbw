require "rails_helper"

RSpec.describe ProfileChangeRequest, type: :model do
  describe "validations" do
    it "requires a requested_value for auto-appliable fields" do
      request = build(:profile_change_request, :primary_email, requested_value: nil)
      expect(request).not_to be_valid
      expect(request.errors[:requested_value]).to be_present
    end

    it "requires a valid email for a primary_email request" do
      request = build(:profile_change_request, :primary_email, requested_value: "not-an-email")
      expect(request).not_to be_valid
    end

    it "requires a valid email for a secondary_email request" do
      request = build(:profile_change_request, :secondary_email, requested_value: "not-an-email")
      expect(request).not_to be_valid
    end

    it "accepts an other request with only details" do
      expect(build(:profile_change_request, :other)).to be_valid
    end

    it "requires details for an other request" do
      request = build(:profile_change_request, :other, details: nil)
      expect(request).not_to be_valid
      expect(request.errors[:details]).to be_present
    end

    describe "work address requests" do
      let(:affiliation) { create(:affiliation) }
      let(:typed) { { proposed_street_address: "12 Elm St", proposed_city: "Reno", proposed_state: "NV", proposed_zip_code: "89501" } }

      [ ProfileChangeRequest::AFFILIATION_CHANGE_WORK_ADDRESS, ProfileChangeRequest::AFFILIATION_CHANGE_UPDATE_WORK_ADDRESS ].each do |change|
        context change do
          let(:base) { { person: affiliation.person, affiliation: affiliation, requested_value: change, details: nil } }

          it "needs a picked address or a street, city, and state" do
            request = build(:profile_change_request, **base, proposed_city: "Reno")
            expect(request).not_to be_valid
            expect(request.errors[:base]).to include("Enter the street, city, and state of your work address")
          end

          it "is auto-appliable with a typed address and no details" do
            request = build(:profile_change_request, **base, **typed)
            expect(request).to be_valid
            expect(request).to be_auto_appliable
            expect(request.proposed_change_summary).to eq("12 Elm St, Reno, NV 89501")
          end

          it "is auto-appliable with an address picked from the org's list, dropping any typed one" do
            address = create(:address, addressable: affiliation.organization)
            request = build(:profile_change_request, **base, **typed, proposed_organization_address: address)
            expect(request).to be_valid
            expect(request).to be_auto_appliable
            expect(request.proposed_city).to be_nil
            expect(request.proposed_change_summary).to eq(address.name)
          end
        end
      end

      it "asks to pick or enter one when the org has addresses on file" do
        create(:address, addressable: affiliation.organization)
        request = build(:profile_change_request, person: affiliation.person, affiliation: affiliation, details: nil,
                                                 requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_UPDATE_WORK_ADDRESS)
        expect(request).not_to be_valid
        expect(request.errors[:base]).to include("Pick an address from the list, or enter its street, city, and state")
      end

      it "rejects another organization's address" do
        request = build(:profile_change_request, person: affiliation.person, affiliation: affiliation, details: nil,
                                                 requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_UPDATE_WORK_ADDRESS,
                                                 proposed_organization_address: create(:address))
        expect(request).not_to be_valid
        expect(request.errors[:proposed_organization_address]).to be_present
      end

      it "leaves an older free-text request for a manual update and still lets it be resolved" do
        request = create(:profile_change_request, person: affiliation.person, affiliation: affiliation, **typed,
                                                  requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_WORK_ADDRESS)
        request.update_columns(proposed_street_address: nil, proposed_city: nil, proposed_state: nil, proposed_zip_code: nil)

        expect(request.reload).not_to be_auto_appliable
        expect { request.resolve!(method: "manual", reviewer: create(:user, :admin)) }.not_to raise_error
      end
    end

    describe "adding an organization that isn't in the portal" do
      let(:add) { { field: "affiliation", requested_value: ProfileChangeRequest::AFFILIATION_CHANGE_ADD, proposed_title: "Counselor", details: nil } }

      it "accepts a typed organization name instead of a picked one" do
        request = build(:profile_change_request, **add, proposed_organization_name: "Hillside Shelter")
        expect(request).to be_valid
        expect(request).to be_new_organization
        expect(request).not_to be_auto_appliable
        expect(request.proposed_change_summary).to include("Hillside Shelter (not in the portal yet)")
      end

      it "needs either a picked organization or a typed name" do
        request = build(:profile_change_request, **add)
        expect(request).not_to be_valid
        expect(request.errors[:base].join).to include("type its name")
      end

      it "drops the typed name when an organization is picked" do
        request = build(:profile_change_request, **add, organization: create(:organization), proposed_organization_name: "Typo")
        request.validate
        expect(request.proposed_organization_name).to be_nil
        expect(request).to be_auto_appliable
      end
    end

    it "requires details for a free-form affiliation request" do
      request = build(:profile_change_request, field: "affiliation", details: nil)
      expect(request).not_to be_valid
      expect(request.errors[:details]).to be_present
    end

    describe "a professional license request" do
      let(:license) { create(:professional_license) }

      it "needs the license and details" do
        expect(build(:profile_change_request, field: "professional_license", person: license.person,
                                              professional_license: license, requested_value: nil, details: "New number")).to be_valid
        expect(build(:profile_change_request, field: "professional_license", person: license.person,
                                              professional_license: license, requested_value: nil, details: nil)).not_to be_valid
        expect(build(:profile_change_request, field: "professional_license", person: license.person,
                                              requested_value: nil, details: "New number")).not_to be_valid
      end

      it "rejects another person's license" do
        request = build(:profile_change_request, field: "professional_license", professional_license: license,
                                                 requested_value: nil, details: "New number")
        expect(request).not_to be_valid
        expect(request.errors[:professional_license]).to be_present
      end

      it "allows one pending request per license" do
        attrs = { field: "professional_license", person: license.person, professional_license: license, requested_value: nil, details: "New number" }
        create(:profile_change_request, **attrs)
        other_license = create(:professional_license, person: license.person, number: "999")

        expect(build(:profile_change_request, **attrs)).not_to be_valid
        expect(build(:profile_change_request, **attrs, professional_license: other_license)).to be_valid
      end

      it "is handled by hand" do
        expect(build(:profile_change_request, field: "professional_license", professional_license: license)).not_to be_auto_appliable
      end
    end

    describe "email requests" do
      let(:person) { create(:person, email_2: "second@example.com", email_2_type: "work") }

      it "accepts a type-only change" do
        expect(build(:profile_change_request, :secondary_email, person: person,
                                                                requested_value: "second@example.com", proposed_email_type: "personal")).to be_valid
      end

      it "rejects a request that matches what's on file" do
        request = build(:profile_change_request, :secondary_email, person: person,
                                                                   requested_value: "Second@example.com", proposed_email_type: "work")
        expect(request).not_to be_valid
        expect(request.errors[:base].join).to include("already what's on file")
      end

      it "rejects an unknown type" do
        expect(build(:profile_change_request, :secondary_email, person: person, proposed_email_type: "pager")).not_to be_valid
      end

      it "starts from the address and type on file" do
        request = build(:profile_change_request, :secondary_email, person: person, requested_value: nil)
        request.prefill_current_email
        expect(request).to have_attributes(requested_value: "second@example.com", proposed_email_type: "work")
      end
    end

    it "rejects an unknown field" do
      request = build(:profile_change_request, field: "shoe_size")
      expect(request).not_to be_valid
    end

    it "rejects an affiliation that belongs to a different person" do
      other_affiliation = create(:affiliation)
      request = build(:profile_change_request, field: "affiliation", affiliation: other_affiliation)
      expect(request).not_to be_valid
      expect(request.errors[:affiliation]).to be_present
    end
  end

  describe "#auto_appliable?" do
    it "is true for the email fields and organization_name, false for affiliation" do
      expect(build(:profile_change_request, :primary_email)).to be_auto_appliable
      expect(build(:profile_change_request, :organization_name)).to be_auto_appliable
      expect(build(:profile_change_request, :secondary_email)).to be_auto_appliable
      expect(build(:profile_change_request, field: "affiliation")).not_to be_auto_appliable
      expect(build(:profile_change_request, :other)).not_to be_auto_appliable
    end
  end

  describe "#current_value" do
    it "reads the person's user email for primary_email" do
      user = create(:user, :with_person, email: "current@example.com")
      request = build(:profile_change_request, :primary_email, person: user.person)
      expect(request.current_value).to eq("current@example.com")
    end

    it "reads the person's email_2 for secondary_email" do
      person = create(:person, email_2: "second-current@example.com")
      request = build(:profile_change_request, :secondary_email, person: person)
      expect(request.current_value).to eq("second-current@example.com")
    end
  end

  describe "#resolve! and #decline!" do
    let(:reviewer) { create(:user, :admin) }
    let(:request) { create(:profile_change_request) }

    it "resolves with a method and reviewer" do
      request.resolve!(method: "manual", reviewer: reviewer)
      expect(request).to be_resolved
      expect(request.resolution_method).to eq("manual")
      expect(request.reviewed_by).to eq(reviewer)
      expect(request.reviewed_at).to be_present
    end

    it "declines with a reviewer" do
      request.decline!(reviewer: reviewer)
      expect(request).to be_declined
      expect(request.reviewed_by).to eq(reviewer)
    end
  end
end
