require "rails_helper"

RSpec.describe Analytics::PersonActivityEvents do
  let(:person) { create(:person) }
  let(:visit) { create(:ahoy_visit) }

  def event(resource_type:, resource_id:, name: "update.record", properties: {})
    create(
      :ahoy_event,
      visit: visit,
      name: name,
      resource_type: resource_type,
      resource_id: resource_id,
      properties: { "resource_type" => resource_type, "resource_id" => resource_id }.merge(properties)
    )
  end

  describe "#relation" do
    it "includes events about the person record" do
      target = event(resource_type: "Person", resource_id: person.id, name: "update.person")
      expect(described_class.new(person).relation).to include(target)
    end

    it "includes lifecycle events about the person's user account" do
      target = event(resource_type: "User", resource_id: person.user.id, name: "update.user")
      expect(described_class.new(person).relation).to include(target)
    end

    it "includes auth events for the person's user (matched via JSON record_id)" do
      target = create(
        :ahoy_event,
        visit: visit,
        name: "auth.login",
        resource_type: nil,
        resource_id: nil,
        properties: { "record_id" => person.user.id, "record_type" => "User" }
      )
      expect(described_class.new(person).relation).to include(target)
    end

    it "includes events about associated data (e.g. the person's payments)" do
      payment = create(:payment, person: person)
      target = event(resource_type: "Payment", resource_id: payment.id, name: "create.payment")
      expect(described_class.new(person).relation).to include(target)
    end

    it "includes events about the person's continuing education registrations" do
      registration = create(:event_registration, registrant: person)
      ce = create(:continuing_education_registration, event_registration: registration)
      target = event(resource_type: "ContinuingEducationRegistration", resource_id: ce.id,
                     name: "update.continuing_education_registration")
      expect(described_class.new(person).relation).to include(target)
    end

    it "includes events about comments connected to the person's associated records" do
      scholarship = create(:scholarship, recipient: person)
      comment = create(:comment, commentable: scholarship)
      target = event(resource_type: "Comment", resource_id: comment.id, name: "create.comment")
      expect(described_class.new(person).relation).to include(target)
    end

    # These records only reach a person through a parent, so the mapping is the
    # only thing putting them on the history — one example per hop.
    describe "records that reach the person through a parent" do
      let(:registration) { create(:event_registration, registrant: person) }

      it "includes the registration's checklist completions, org links, and attendance entries" do
        completion = create(:event_registration_checklist_completion, event_registration: registration)
        org_link = create(:event_registration_organization, event_registration: registration)
        entry = create(:event_attendance_time_entry, event_registration: registration)

        relation = described_class.new(person).relation

        expect(relation).to include(event(resource_type: "EventRegistrationChecklistCompletion", resource_id: completion.id))
        expect(relation).to include(event(resource_type: "EventRegistrationOrganization", resource_id: org_link.id))
        expect(relation).to include(event(resource_type: "EventAttendanceTimeEntry", resource_id: entry.id))
      end

      it "includes the events they staff" do
        staffing = create(:event_staff, person: person)

        expect(described_class.new(person).relation)
          .to include(event(resource_type: "EventStaff", resource_id: staffing.id))
      end

      it "includes their membership invoices" do
        invoice = create(:membership_invoice, membership: create(:membership, person: person))

        expect(described_class.new(person).relation)
          .to include(event(resource_type: "MembershipInvoice", resource_id: invoice.id))
      end

      it "includes allocations against anything they owe" do
        payment = create(:payment, person: person)
        invoice = create(:membership_invoice, membership: create(:membership, person: person))
        ce = create(:continuing_education_registration, event_registration: registration)
        targets = [ registration, invoice, ce ].map do |allocatable|
          allocation = create(:allocation, source: payment, allocatable: allocatable)
          [ allocatable.class.name, event(resource_type: "Allocation", resource_id: allocation.id) ]
        end

        relation = described_class.new(person).relation

        targets.each do |allocatable_type, target|
          expect(relation).to include(target), "expected the #{allocatable_type} allocation on the history"
        end
      end

      it "includes refunds they receive and refunds reversing their payments" do
        theirs = create(:refund, recipient: person, refundable: create(:payment, person: person))
        on_their_payment = create(:refund, recipient: create(:organization), refundable: create(:payment, person: person))

        relation = described_class.new(person).relation

        expect(relation).to include(event(resource_type: "Refund", resource_id: theirs.id))
        expect(relation).to include(event(resource_type: "Refund", resource_id: on_their_payment.id))
      end

      it "includes their form answers and the uploads attached to them" do
        answer = create(:form_answer, form_submission: create(:form_submission, person: person))
        asset = create(:asset, owner: answer)

        relation = described_class.new(person).relation

        expect(relation).to include(event(resource_type: "FormAnswer", resource_id: answer.id))
        expect(relation).to include(event(resource_type: "Asset", resource_id: asset.id))
      end

      it "includes responses to their scholarship agreements" do
        response = create(:scholarship_agreement_response, scholarship: create(:scholarship, recipient: person))

        expect(described_class.new(person).relation)
          .to include(event(resource_type: "ScholarshipAgreementResponse", resource_id: response.id))
      end

      it "excludes the same record types when they belong to someone else" do
        other_registration = create(:event_registration)
        completion = create(:event_registration_checklist_completion, event_registration: other_registration)
        allocation = create(:allocation, allocatable: other_registration)

        relation = described_class.new(person).relation

        expect(relation).not_to include(event(resource_type: "EventRegistrationChecklistCompletion", resource_id: completion.id))
        expect(relation).not_to include(event(resource_type: "Allocation", resource_id: allocation.id))
      end
    end

    # Most mapped types have no dedicated inclusion example above, so a typo or
    # model rename in a key would silently drop that type from the history. This
    # guard derives from the map itself and fails loudly instead.
    it "keys the map only on real trackable model classes" do
      map = described_class.new(person).send(:resource_ids_by_type)

      map.each_key do |resource_type|
        klass = resource_type.safe_constantize
        expect(klass).to be_present, "#{resource_type} is not a real constant"
        expect(klass).to be < ApplicationRecord
      end
    end

    it "excludes events unrelated to the person" do
      unrelated_person = create(:person)
      other = event(resource_type: "Person", resource_id: unrelated_person.id, name: "update.person")
      auth_for_other = create(
        :ahoy_event,
        visit: visit,
        name: "auth.login",
        properties: { "record_id" => unrelated_person.user.id, "record_type" => "User" }
      )

      relation = described_class.new(person).relation
      expect(relation).not_to include(other)
      expect(relation).not_to include(auth_for_other)
    end

    it "returns no events when the person has none" do
      event(resource_type: "Workshop", resource_id: 999, name: "view.workshop")
      expect(described_class.new(person).relation).to be_empty
    end
  end

  describe "#count" do
    it "counts the person's, their user's, and associated data's events" do
      event(resource_type: "Person", resource_id: person.id, name: "update.person")
      event(resource_type: "User", resource_id: person.user.id, name: "update.user")
      payment = create(:payment, person: person)
      event(resource_type: "Payment", resource_id: payment.id, name: "create.payment")
      event(resource_type: "Person", resource_id: create(:person).id, name: "update.person")

      expect(described_class.new(person).count).to eq(3)
    end
  end
end
