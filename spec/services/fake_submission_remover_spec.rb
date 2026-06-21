require "rails_helper"

RSpec.describe FakeSubmissionRemover do
  # The :person factory associates a User by default; real fake-form people have
  # none, so deletable candidates are built with user: nil.

  describe "#call deleting by person id" do
    let!(:person) { create(:person, user: nil) }
    let!(:other_person) { create(:person, user: nil) }

    let!(:submission) { create(:form_submission, person: person) }
    let!(:form_field) { create(:form_field, form: submission.form) }
    let!(:answer) { create(:form_answer, form_submission: submission, form_field: form_field) }
    let!(:affiliation) { create(:affiliation, person: person) }
    let!(:registration) { create(:event_registration, registrant: person) }
    let!(:scholarship) { create(:scholarship, recipient: person) }

    # Records NOT cascaded by Person.destroy.
    let!(:payment) { create(:payment, person: person, form_submission: submission) }
    let!(:refund) { create(:refund, refundable: payment) }
    let!(:scholarship_allocation) { create(:allocation, source: scholarship, allocatable: registration) }
    let!(:bulk_notification) do
      create(:notification, noticeable: submission, kind: :bulk_payment_confirmation, recipient_role: :person)
    end
    let!(:pay_customer) do
      Pay::Customer.create!(owner: person, processor: "stripe", processor_id: "cus_fake_#{person.id}")
    end

    # Audit trail for the removed records.
    let!(:payment_version) { PaperTrail::Version.create!(item_type: "Payment", item_id: payment.id, event: "create") }
    let!(:person_event) { create(:ahoy_event, name: "create.person", resource_type: "Person", resource_id: person.id) }
    let!(:submission_event) do
      create(:ahoy_event, name: "create.form_submission", resource_type: "FormSubmission", resource_id: submission.id)
    end

    # An unrelated person's identical graph must survive untouched.
    let!(:other_submission) { create(:form_submission, person: other_person) }
    let!(:other_payment) { create(:payment, person: other_person) }
    let!(:other_event) { create(:ahoy_event, name: "create.person", resource_type: "Person", resource_id: other_person.id) }

    def remove(**opts)
      described_class.new(person_ids: [ person.id ], **opts).call
    end

    it "returns the deleted person ids" do
      expect(remove).to eq [ person.id ]
    end

    it "destroys the person and the full cascaded graph" do
      remove

      expect(Person.exists?(person.id)).to be false
      expect(FormSubmission.exists?(submission.id)).to be false
      expect(FormAnswer.exists?(answer.id)).to be false
      expect(Affiliation.exists?(affiliation.id)).to be false
      expect(EventRegistration.exists?(registration.id)).to be false
      expect(Scholarship.exists?(scholarship.id)).to be false
    end

    it "destroys records not cascaded by Person.destroy" do
      remove

      expect(Payment.exists?(payment.id)).to be false
      expect(Refund.exists?(refund.id)).to be false
      expect(Allocation.exists?(scholarship_allocation.id)).to be false
      expect(Notification.exists?(bulk_notification.id)).to be false
      expect(Pay::Customer.exists?(pay_customer.id)).to be false
    end

    it "deletes the PaperTrail and Ahoy audit trail for the removed records" do
      remove

      expect(PaperTrail::Version.exists?(payment_version.id)).to be false
      expect(Ahoy::Event.exists?(person_event.id)).to be false
      expect(Ahoy::Event.exists?(submission_event.id)).to be false
    end

    it "leaves unrelated people and their data untouched" do
      remove

      expect(Person.exists?(other_person.id)).to be true
      expect(FormSubmission.exists?(other_submission.id)).to be true
      expect(Payment.exists?(other_payment.id)).to be true
      expect(Ahoy::Event.exists?(other_event.id)).to be true
    end
  end

  describe "#call resolving by form submission id" do
    let!(:person) { create(:person, user: nil) }
    let!(:submission) { create(:form_submission, person: person) }

    it "resolves the owning person and deletes them" do
      described_class.new(form_submission_ids: [ submission.id ]).call

      expect(Person.exists?(person.id)).to be false
      expect(FormSubmission.exists?(submission.id)).to be false
    end
  end

  describe "protecting real-looking people" do
    it "skips (does not delete) a person with a linked user account" do
      person = create(:person)
      create(:form_submission, person: person)

      remover = described_class.new(person_ids: [ person.id ])

      expect(remover.call).to be_empty
      expect(Person.exists?(person.id)).to be true
      expect(remover.skipped.map { |s| s.person.id }).to include(person.id)
    end

    it "skips a person who is a grant donor" do
      person = create(:person, user: nil)
      create(:grant, :donated_by_person, donor: person)

      described_class.new(person_ids: [ person.id ]).call

      expect(Person.exists?(person.id)).to be true
    end
  end

  describe "delete_users" do
    it "destroys an unused auto-created account along with the person" do
      person = create(:person)
      user = person.user # factory default: not super_user, never signed in

      described_class.new(person_ids: [ person.id ], delete_users: true).call

      expect(Person.exists?(person.id)).to be false
      expect(User.exists?(user.id)).to be false
    end

    it "still protects a super_user" do
      person = create(:person)
      person.user.update!(super_user: true)

      described_class.new(person_ids: [ person.id ], delete_users: true).call

      expect(Person.exists?(person.id)).to be true
    end

    it "still protects a user who has signed in" do
      person = create(:person)
      person.user.update!(sign_in_count: 3, current_sign_in_at: Time.current)

      described_class.new(person_ids: [ person.id ], delete_users: true).call

      expect(Person.exists?(person.id)).to be true
    end

    it "protects a user with Ahoy activity of its own" do
      person = create(:person)
      create(:ahoy_event, user: person.user, name: "view.workshop")

      described_class.new(person_ids: [ person.id ], delete_users: true).call

      expect(Person.exists?(person.id)).to be true
    end
  end

  describe "force: true (override)" do
    it "deletes a person with an active/admin account and destroys the account" do
      person = create(:person)
      person.user.update!(super_user: true)
      user = person.user

      described_class.new(person_ids: [ person.id ], force: true).call

      expect(Person.exists?(person.id)).to be false
      expect(User.exists?(user.id)).to be false
    end

    it "deletes a grant donor that would otherwise be protected" do
      person = create(:person, user: nil)
      create(:grant, :donated_by_person, donor: person)

      described_class.new(person_ids: [ person.id ], force: true).call

      expect(Person.exists?(person.id)).to be false
    end
  end

  describe "#protection_reasons" do
    it "lists why a person looks real, regardless of force" do
      person = create(:person) # factory gives a User account
      create(:grant, :donated_by_person, donor: person)

      reasons = described_class.new(person_ids: [ person.id ], force: true).protection_reasons(person)

      expect(reasons).to include(a_string_matching(/User account/))
      expect(reasons).to include("is a grant donor")
    end

    it "is empty for a plain fake person" do
      person = create(:person, user: nil)

      expect(described_class.new(person_ids: [ person.id ]).protection_reasons(person)).to be_empty
    end
  end

  describe "account content (force)" do
    it "#blocking_account_content lists FK-restricted content owned by the account" do
      person = create(:person)
      user = person.user
      create(:workshop, created_by: user)
      create(:story, created_by: user)

      blocking = described_class.new(person_ids: [ person.id ], force: true).blocking_account_content

      expect(blocking["Workshops"]).to eq 1
      expect(blocking["Stories"]).to eq 1
      expect(blocking).not_to have_key("Reports")
    end

    it "#cascading_account_content lists records removed with the account" do
      person = create(:person)
      create(:bookmark, user: person.user)

      cascading = described_class.new(person_ids: [ person.id ], force: true).cascading_account_content

      expect(cascading["Bookmarks"]).to eq 1
    end

    it "is empty when there is no linked account" do
      person = create(:person, user: nil)
      remover = described_class.new(person_ids: [ person.id ], force: true)

      expect(remover.blocking_account_content).to be_empty
      expect(remover.cascading_account_content).to be_empty
    end

    it "raises InvalidForeignKey rather than orphaning content when forced" do
      person = create(:person)
      create(:workshop, created_by: person.user)

      expect do
        described_class.new(person_ids: [ person.id ], force: true).call
      end.to raise_error(ActiveRecord::InvalidForeignKey)
      expect(Person.exists?(person.id)).to be true
    end
  end

  describe "#counts" do
    it "reports per-record-type counts without mutating anything" do
      person = create(:person, user: nil)
      create(:form_submission, person: person)

      remover = described_class.new(person_ids: [ person.id ])

      expect(remover.counts[:people]).to eq 1
      expect(remover.counts[:form_submissions]).to eq 1
      expect(Person.exists?(person.id)).to be true
    end
  end
end
