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

    it "includes payment events recorded under the STI subclass the tracker writes" do
      payment = create(:payment, person: person, type: "CashPayment")
      target = event(resource_type: "CashPayment", resource_id: payment.id, name: "create.payment")
      expect(described_class.new(person).relation).to include(target)
    end

    it "includes events about comments on the person's affiliations" do
      comment = create(:comment, commentable: create(:affiliation, person: person))
      target = event(resource_type: "Comment", resource_id: comment.id, name: "create.comment")
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
    describe "comments that have left the person" do
      it "includes a deleted comment's events, found through its delete snapshot" do
        created = event(resource_type: "Comment", resource_id: 9_001, name: "create.comment")
        deleted = event(resource_type: "Comment", resource_id: 9_001, name: "destroy.comment",
                        properties: { "attributes" => { "commentable_type" => "Person", "commentable_id" => person.id } })

        expect(described_class.new(person).relation).to include(created, deleted)
      end

      it "includes a comment moved off the person's records, typed by its logged diff" do
        comment = create(:comment, commentable: create(:user))
        moved = event(resource_type: "Comment", resource_id: comment.id, name: "update.comment",
                      properties: { "changes" => {
                        "commentable_id" => { "before" => person.id, "after" => comment.commentable_id },
                        "commentable_type" => { "before" => "Person", "after" => "User" }
                      } })

        expect(described_class.new(person).relation).to include(moved)
      end

      it "includes a same-type move logged without its type, read off the comment" do
        comment = create(:comment, commentable: create(:person))
        moved = event(resource_type: "Comment", resource_id: comment.id, name: "update.comment",
                      properties: { "changes" => { "commentable_id" => { "before" => person.id, "after" => comment.commentable_id } } })

        expect(described_class.new(person).relation).to include(moved)
      end

      it "excludes deleted and moved comments that were never on the person's records" do
        other = create(:person)
        comment = create(:comment, commentable: create(:person))
        deleted = event(resource_type: "Comment", resource_id: 9_002, name: "destroy.comment",
                        properties: { "attributes" => { "commentable_type" => "Person", "commentable_id" => other.id } })
        moved = event(resource_type: "Comment", resource_id: comment.id, name: "update.comment",
                      properties: { "changes" => { "commentable_id" => { "before" => other.id, "after" => comment.commentable_id } } })

        expect(described_class.new(person).relation).not_to include(deleted, moved)
      end
    end

    describe "deleted records" do
      def deleted(type, id, attributes)
        event(resource_type: type, resource_id: id, name: "destroy.#{type.constantize.table_name.singularize}",
              properties: { "attributes" => attributes })
      end

      it "includes a deleted record's whole history, found through its delete snapshot" do
        created = event(resource_type: "Affiliation", resource_id: 9_101, name: "create.affiliation")
        destroyed = deleted("Affiliation", 9_101, "person_id" => person.id)

        expect(described_class.new(person).relation).to include(created, destroyed)
      end

      it "matches a polymorphic owner by its type and id" do
        address = deleted("Address", 9_102, "addressable_type" => "Person", "addressable_id" => person.id)
        not_theirs = deleted("Address", 9_103, "addressable_type" => "Organization", "addressable_id" => person.id)

        relation = described_class.new(person).relation
        expect(relation).to include(address)
        expect(relation).not_to include(not_theirs)
      end

      it "follows a deleted record's children through the deleted parent" do
        registration = deleted("EventRegistration", 9_104, "registrant_id" => person.id)
        ce = deleted("ContinuingEducationRegistration", 9_105, "event_registration_id" => 9_104)
        allocation = deleted("Allocation", 9_106, "allocatable_type" => "ContinuingEducationRegistration", "allocatable_id" => 9_105)

        expect(described_class.new(person).relation).to include(registration, ce, allocation)
      end

      it "matches a deleted child of a record that still exists" do
        live = create(:event_registration, registrant: person)
        entry = deleted("EventAttendanceTimeEntry", 9_107, "event_registration_id" => live.id)

        expect(described_class.new(person).relation).to include(entry)
      end

      it "keys a deleted STI payment under its subclass and matches its refunds via the base class" do
        payment = deleted("CashPayment", 9_108, "person_id" => person.id)
        refund = deleted("Refund", 9_109, "refundable_type" => "Payment", "refundable_id" => 9_108)

        expect(described_class.new(person).relation).to include(payment, refund)
      end

      it "includes a comment left on a deleted record" do
        deleted("Affiliation", 9_110, "person_id" => person.id)
        comment = deleted("Comment", 9_111, "commentable_type" => "Affiliation", "commentable_id" => 9_110)

        expect(described_class.new(person).relation).to include(comment)
      end

      it "includes the login events of the person's deleted user account" do
        person.user.update_columns(person_id: nil)
        deleted("User", 9_114, "person_id" => person.id)
        login = create(:ahoy_event, visit: visit, name: "auth.login",
                                    properties: { "record_id" => 9_114, "record_type" => "User" })

        expect(described_class.new(person).relation).to include(login)
      end

      it "excludes deleted records that belonged to someone else" do
        other = create(:person)
        theirs = deleted("Affiliation", 9_112, "person_id" => other.id)
        their_child = deleted("ContinuingEducationRegistration", 9_113, "event_registration_id" => 9_999)

        relation = described_class.new(person).relation
        expect(relation).not_to include(theirs)
        expect(relation).not_to include(their_child)
      end

      it "maps an owner column for every record type in the history" do
        owners = described_class::DELETED_RECORD_OWNERS
        map = described_class.new(person).send(:resource_ids_by_type)

        expect(owners.keys).to match_array(map.keys - %w[Person Comment])
        owners.each do |type, columns|
          klass = type.constantize
          columns.each_key do |column|
            known = klass.column_names.include?(column) || klass.reflect_on_association(column)&.polymorphic?
            expect(known).to be(true), "#{type} has no #{column} column or polymorphic belongs_to"
          end
        end
      end
    end

    describe "#deleted_comment_events" do
      def deleted_comment(id, commentable_type, commentable_id)
        event(resource_type: "Comment", resource_id: id, name: "destroy.comment",
              properties: { "attributes" => { "commentable_type" => commentable_type, "commentable_id" => commentable_id } })
      end

      it "lists comments deleted from the person's live and deleted records, newest first" do
        on_profile = deleted_comment(9_201, "Person", person.id)
        event(resource_type: "Affiliation", resource_id: 9_202, name: "destroy.affiliation",
              properties: { "attributes" => { "person_id" => person.id } })
        on_deleted_parent = deleted_comment(9_203, "Affiliation", 9_202)

        expect(described_class.new(person).deleted_comment_events).to eq([ on_deleted_parent, on_profile ])
      end

      it "leaves out comments deleted from someone else's records" do
        deleted_comment(9_204, "Person", create(:person).id)
        expect(described_class.new(person).deleted_comment_events).to be_empty
      end
    end

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
