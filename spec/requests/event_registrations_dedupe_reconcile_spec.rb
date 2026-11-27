# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Event registration dedupe — reconciling the merge", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, start_date: 2.days.ago, end_date: 1.day.ago) }
  let(:keep_person) { create(:person) }
  let(:delete_person) { create(:person) }
  let!(:keep_reg) { create(:event_registration, registrant: keep_person, event: event) }
  let!(:delete_reg) { create(:event_registration, registrant: delete_person, event: event) }

  before { sign_in admin }

  def merge!(keep_fields = {})
    post dedupe_perform_event_registrations_path, params: {
      event_registration_to_keep_id: keep_reg.id,
      event_registration_to_delete_id: delete_reg.id,
      event_registration_to_keep: keep_fields
    }.compact_blank
  end

  def preview!
    get dedupe_preview_event_registrations_path(
      event_registration_to_keep_id: keep_reg.id,
      event_registration_to_delete_id: delete_reg.id
    )
  end

  it "relinks bulk payments that named the deleted registration" do
    submission = create(:form_submission, metadata: { "linked_registration_ids" => [ delete_reg.id ] })

    merge!

    expect(submission.reload.linked_registration_ids).to eq([ keep_reg.id ])
  end

  it "combines both registrations' FileMaker codes" do
    keep_reg.update!(filemaker_code: "P1")
    delete_reg.update!(filemaker_code: "P2")

    merge!(filemaker_code: "P1")

    expect(keep_reg.reload.filemaker_codes).to contain_exactly("P1", "P2")
  end

  it "saves the attendance days picked on the preview and re-syncs the status" do
    merge!(completed_day_1: "1", completed_day_2: "1")

    keep_reg.reload
    expect(keep_reg.completed_day_1).to be true
    expect(keep_reg.status).to eq("attended")
  end

  it "keeps a status set without day flags when no days change" do
    keep_reg.update!(status: "attended")

    merge!

    expect(keep_reg.reload.status).to eq("attended")
  end

  it "shows the attendance and certificate columns on the preview" do
    delete_reg.update!(certificate_sent_at: 1.hour.ago)

    preview!

    expect(response.body).to include("Completed day 1", "Certificate sent at", "Post survey completed at")
  end

  it "shows only as many attendance days as the longer event has" do
    preview!

    expect(response.body).to include("Completed day 2")
    expect(response.body).not_to include("Completed day 3")
  end

  it "warns on the preview that the deleted registration's ticket link stops working" do
    preview!

    expect(response.body).to include("ticket link stops working")
  end

  it "carries the deleted org link's submission pin onto the keeper's link to the same org" do
    organization = create(:organization)
    submission = create(:form_submission, person: delete_person)
    create(:event_registration_organization, event_registration: keep_reg, organization: organization)
    create(:event_registration_organization, event_registration: delete_reg, organization: organization,
      form_submission: submission)

    merge!

    link = keep_reg.reload.event_registration_organizations.sole
    expect(link.form_submission_id).to eq(submission.id)
  end

  it "unlinks affiliations the deleted registration minted for its own registrant" do
    affiliation = create(:affiliation, person: delete_person, event_registration: delete_reg)

    merge!

    expect(affiliation.reload.event_registration_id).to be_nil
  end

  it "blocks the merge while the deleted registration's Stripe checkout is unfinished" do
    delete_reg.update!(checkout_session_id: "cs_test_123")

    expect { merge! }.not_to change(EventRegistration, :count)
    expect(flash[:alert]).to include("Stripe checkout")
  end

  it "merges once the checkout is paid" do
    delete_reg.update!(checkout_session_id: "cs_test_123", payment_unresolved: false)

    expect { merge! }.to change(EventRegistration, :count).by(-1)
  end

  context "with sign-in times on both registrations" do
    let(:day) { event.start_date.in_time_zone.change(hour: 9) }

    before do
      create(:event_attendance_time_entry, event_registration: keep_reg, signed_in_at: day, signed_out_at: day + 3.hours)
    end

    it "blocks the merge when the times overlap" do
      create(:event_attendance_time_entry, event_registration: delete_reg,
        signed_in_at: day + 1.hour, signed_out_at: day + 2.hours)

      preview!
      expect(response.body).to include("sign-in times on")

      expect { merge! }.not_to change(EventRegistration, :count)
      expect(flash[:alert]).to include("overlap")
    end

    it "merges times that don't overlap" do
      create(:event_attendance_time_entry, event_registration: delete_reg,
        signed_in_at: day + 4.hours, signed_out_at: day + 5.hours)

      expect { merge! }.to change(EventRegistration, :count).by(-1)
      expect(keep_reg.reload.event_attendance_time_entries.count).to eq(2)
    end
  end

  # Merging the two people collapses their registrations for one event.
  describe "merging the registrants" do
    def merge_people!
      post dedupe_perform_people_path, params: {
        person_to_keep_id: keep_person.id,
        person_to_delete_id: delete_person.id
      }
    end

    it "keeps the attendance days and relinks bulk payments of the collapsed registration" do
      delete_reg.update!(completed_day_1: true, completed_day_2: true)
      submission = create(:form_submission, metadata: { "linked_registration_ids" => [ delete_reg.id ] })

      merge_people!

      expect(EventRegistration.exists?(delete_reg.id)).to be false
      keep_reg.reload
      expect(keep_reg.completed_day_2).to be true
      expect(keep_reg.status).to eq("attended")
      expect(submission.reload.linked_registration_ids).to eq([ keep_reg.id ])
    end

    it "blocks the people merge while the collapsing registration's checkout is unfinished" do
      delete_reg.update!(checkout_session_id: "cs_test_123")

      expect { merge_people! }.not_to change(Person, :count)
      expect(flash[:alert]).to include("Stripe checkout")
    end
  end
end
