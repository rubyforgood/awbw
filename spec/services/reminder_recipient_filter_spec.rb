require "rails_helper"

RSpec.describe ReminderRecipientFilter do
  let(:event) { create(:event, cost_cents: 10_000) }

  def registration(first_name: "Jane", last_name: "Doe", **person_attrs)
    person = create(:person, first_name: first_name, last_name: last_name, **person_attrs)
    create(:event_registration, event: event, registrant: person)
  end

  def award_scholarship(reg, grant: nil, tasks_completed: false)
    scholarship = create(:scholarship, recipient: reg.registrant, grant: grant, tasks_completed: tasks_completed)
    create(:allocation, allocatable: reg, source: scholarship, amount: scholarship.amount_cents)
    scholarship
  end

  def matched(params, registrations)
    described_class.new(registrations, ActionController::Parameters.new(params)).matched_ids
  end

  describe "#filtering?" do
    it "is false with no filter params and true once any filter is set" do
      expect(described_class.new([], ActionController::Parameters.new({})).filtering?).to be(false)
      expect(described_class.new([], ActionController::Parameters.new(name: "x")).filtering?).to be(true)
    end
  end

  describe "#matched_ids" do
    it "matches everyone when no filters are applied" do
      regs = [ registration, registration(first_name: "Sam") ]
      expect(matched({}, regs)).to eq(regs.map(&:id).to_set)
    end

    it "filters by registrant name" do
      jane = registration(first_name: "Jane")
      sam = registration(first_name: "Samuel")
      expect(matched({ name: "jane" }, [ jane, sam ])).to eq([ jane.id ].to_set)
    end

    it "matches any of several names separated by --" do
      amy = registration(first_name: "Amy")
      aisha = registration(first_name: "Aisha")
      sam = registration(first_name: "Sam")
      expect(matched({ name: "amy--aisha" }, [ amy, aisha, sam ])).to eq([ amy.id, aisha.id ].to_set)
    end

    it "preserves single hyphens inside a name term" do
      hyphen = registration(first_name: "Mary", last_name: "Jane-Wells")
      other = registration(first_name: "Sam")
      expect(matched({ name: "jane-wells" }, [ hyphen, other ])).to eq([ hyphen.id ].to_set)
    end

    it "matches any of several organization names separated by --" do
      hope = registration(first_name: "Hope").tap { |r| r.organizations << create(:organization, name: "Hope Center") }
      unity = registration(first_name: "Unity").tap { |r| r.organizations << create(:organization, name: "Unity House") }
      other = registration(first_name: "Sam").tap { |r| r.organizations << create(:organization, name: "Elsewhere") }
      expect(matched({ reg_org: "hope--unity" }, [ hope, unity, other ])).to eq([ hope.id, unity.id ].to_set)
    end

    it "filters by registration organization name" do
      reg = registration
      reg.organizations << create(:organization, name: "Hope Center")
      other = registration(first_name: "Sam")
      expect(matched({ reg_org: "hope" }, [ reg, other ])).to eq([ reg.id ].to_set)
    end

    it "filters by funder name of an associated grant" do
      funder = create(:organization, name: "Acme Foundation")
      grant = create(:grant, funder: funder)
      reg = registration
      award_scholarship(reg, grant: grant)
      ungranted = registration(first_name: "Sam")
      award_scholarship(ungranted) # scholarship with no grant
      expect(matched({ funder_name: "acme" }, [ reg, ungranted ])).to eq([ reg.id ].to_set)
    end

    it "filters by email address" do
      amy = registration(first_name: "Amy", email: "amy@example.com", user: nil)
      sam = registration(first_name: "Sam", email: "sam@example.com", user: nil)
      expect(matched({ email: "amy@example" }, [ amy, sam ])).to eq([ amy.id ].to_set)
    end

    it "matches any of several emails separated by --" do
      amy = registration(first_name: "Amy", email: "amy@example.com", user: nil)
      aisha = registration(first_name: "Aisha", email: "aisha@example.com", user: nil)
      sam = registration(first_name: "Sam", email: "sam@other.com", user: nil)
      expect(matched({ email: "amy@--aisha@" }, [ amy, aisha, sam ])).to eq([ amy.id, aisha.id ].to_set)
    end

    it "filters by registration comment text" do
      reg = registration
      create(:comment, :for_event_registration, commentable: reg, body: "Needs a payment plan")
      other = registration(first_name: "Sam")
      expect(matched({ comment: "payment plan" }, [ reg, other ])).to eq([ reg.id ].to_set)
    end

    context "payment status" do
      let!(:paid) { registration.tap { |r| create(:allocation, allocatable: r, amount: 10_000) } }
      let!(:due) { registration(first_name: "Due") }
      let!(:intends) { registration(first_name: "Intends").tap { |r| r.update!(intends_to_pay: true) } }

      it "filters paid registrants" do
        expect(matched({ payment_status: "paid" }, [ paid, due, intends ])).to eq([ paid.id ].to_set)
      end

      it "filters due registrants" do
        expect(matched({ payment_status: "unpaid" }, [ paid, due, intends ])).to eq([ due.id, intends.id ].to_set)
      end

      it "filters intends-to-pay registrants" do
        expect(matched({ payment_status: "intends_to_pay" }, [ paid, due, intends ])).to eq([ intends.id ].to_set)
      end
    end

    context "payment method" do
      let!(:card) { registration(first_name: "Card").tap { |r| r.update!(expected_payment_method: "Credit card (now)") } }
      let!(:check) { registration(first_name: "Check").tap { |r| r.update!(expected_payment_method: "Check") } }
      let!(:buddy) { registration(first_name: "Buddy").tap { |r| r.update!(someone_else_will_pay: true) } }

      it "filters by the expected payment method" do
        expect(matched({ payment_method: "Check" }, [ card, check, buddy ])).to eq([ check.id ].to_set)
      end

      it "filters buddy-system registrants via the sentinel value" do
        expect(matched({ payment_method: "someone_else_will_pay" }, [ card, check, buddy ])).to eq([ buddy.id ].to_set)
      end
    end

    # Shares the registrants-roster `scholarship` filter (yes/complete/incomplete).
    context "scholarship" do
      let!(:none) { registration.tap { |r| r.update!(scholarship_requested: true) } }
      let!(:allocated) { registration(first_name: "Alloc").tap { |r| award_scholarship(r) } }
      let!(:completed) { registration(first_name: "Done").tap { |r| award_scholarship(r, tasks_completed: true) } }

      it "filters all recipients" do
        expect(matched({ scholarship: "yes" }, [ none, allocated, completed ]))
          .to eq([ allocated.id, completed.id ].to_set)
      end

      it "filters tasks complete" do
        expect(matched({ scholarship: "complete" }, [ none, allocated, completed ]))
          .to eq([ completed.id ].to_set)
      end

      it "filters tasks not complete" do
        expect(matched({ scholarship: "incomplete" }, [ none, allocated, completed ]))
          .to eq([ allocated.id ].to_set)
      end
    end

    context "account status" do
      let!(:no_account) { registration(first_name: "None", user: nil) }
      let!(:has_access) { registration(first_name: "Open") }
      let!(:invited) do
        registration(first_name: "Invited").tap do |r|
          r.registrant.user.update!(confirmed_at: nil, welcome_instructions_sent_at: Time.current)
        end
      end
      let!(:no_access) do
        registration(first_name: "Locked").tap do |r|
          r.registrant.user.update!(confirmed_at: nil, welcome_instructions_sent_at: nil)
        end
      end
      let(:regs) { [ no_account, has_access, invited, no_access ] }

      it "filters no account" do
        expect(matched({ account_status: "none" }, regs)).to eq([ no_account.id ].to_set)
      end

      it "filters has access" do
        expect(matched({ account_status: "has_access" }, regs)).to eq([ has_access.id ].to_set)
      end

      it "filters invited" do
        expect(matched({ account_status: "invited" }, regs)).to eq([ invited.id ].to_set)
      end

      it "filters no access" do
        expect(matched({ account_status: "no_access" }, regs)).to eq([ no_access.id ].to_set)
      end
    end

    context "CE status" do
      # Requested CE, supplied a license, and paid the CE balance in full.
      let!(:complete) do
        registration(first_name: "Complete").tap do |r|
          license = create(:professional_license, person: r.registrant, number: "ABC123")
          ce_reg = create(:continuing_education_registration, event_registration: r, professional_license: license, hours: 4)
          payment = create(:payment, amount_cents: ce_reg.cost_cents, amount_cents_remaining: ce_reg.cost_cents)
          create(:allocation, source: payment, allocatable: ce_reg, amount: ce_reg.cost_cents)
        end
      end
      # CE on a placeholder license, unpaid.
      let!(:missing) do
        registration(first_name: "Missing").tap do |r|
          license = create(:professional_license, :placeholder, person: r.registrant)
          create(:continuing_education_registration, event_registration: r, professional_license: license, hours: 4)
        end
      end
      # CE with a license on file but the balance unpaid.
      let!(:unpaid_known) do
        registration(first_name: "Unpaid").tap do |r|
          license = create(:professional_license, person: r.registrant, number: "XYZ789")
          create(:continuing_education_registration, event_registration: r, professional_license: license, hours: 4)
        end
      end
      # No CE registration at all.
      let!(:no_ce) { registration(first_name: "None") }
      let(:regs) { [ complete, missing, unpaid_known, no_ce ] }

      it "filters CE not yet paid" do
        expect(matched({ ce_status: "requested" }, regs)).to eq([ missing.id, unpaid_known.id ].to_set)
      end

      it "filters CE on a placeholder license" do
        expect(matched({ ce_status: "needs_license" }, regs)).to eq([ missing.id ].to_set)
      end

      it "filters CE paid (CE balance paid in full)" do
        expect(matched({ ce_status: "paid" }, regs)).to eq([ complete.id ].to_set)
      end
    end

    it "combines filters with AND" do
      funder = create(:organization, name: "Acme Foundation")
      grant = create(:grant, funder: funder)
      match = registration(first_name: "Jane", last_name: "Adams").tap { |r| award_scholarship(r, grant: grant) }
      name_only = registration(first_name: "Jane", last_name: "Brooks")
      funder_only = registration(first_name: "Sam", last_name: "Cole").tap { |r| award_scholarship(r, grant: grant) }
      expect(matched({ name: "jane", funder_name: "acme" }, [ match, name_only, funder_only ]))
        .to eq([ match.id ].to_set)
    end
  end
end
