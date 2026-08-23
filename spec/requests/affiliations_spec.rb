require "rails_helper"

RSpec.describe "/affiliations", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let!(:affiliation) do
    create(:affiliation, organization: organization, person: person, title: "Facilitator")
  end

  describe "GET /affiliations/:id/edit" do
    context "as an admin" do
      before { sign_in admin }

      it "renders the edit form" do
        get edit_affiliation_path(affiliation)
        expect(response).to be_successful
      end

      it "surfaces the FileMaker code field" do
        get edit_affiliation_path(affiliation)

        expect(response.body).to include("affiliation[filemaker_code]")
      end

      it "hides the registration picker outside admin mode, showing the read-only banner instead" do
        registration = create(:event_registration, registrant: person)
        affiliation.update_column(:event_registration_id, registration.id)

        get edit_affiliation_path(affiliation)

        expect(response.body).not_to include("Linked registration")
        expect(response.body).to include(link_organization_event_registration_path(registration))
      end

      it "in admin mode offers the person's registrations, labelled with the linked org" do
        event = create(:event, title: "Spring Training")
        org = create(:organization, name: "Sunrise House")
        registration = create(:event_registration, registrant: person, event: event, organizations: [ org ])

        get edit_affiliation_path(affiliation, admin: "true")

        expect(response.body).to include("Linked registration")
        expect(response.body).to include("Spring Training")
        expect(response.body).to include("Sunrise House")
        expect(response.body).to include(%(value="#{registration.id}"))
      end

      it "in admin mode keeps the current link selectable even when it isn't the person's own" do
        registration = create(:event_registration)
        affiliation.update_column(:event_registration_id, registration.id)

        get edit_affiliation_path(affiliation, admin: "true")

        expect(response.body).to include(%(value="#{registration.id}"))
        expect(response.body).to include(edit_event_registration_path(registration))
      end
    end

    context "as a non-admin" do
      before { sign_in regular_user }

      it "redirects to root" do
        get edit_affiliation_path(affiliation)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /affiliations/:id" do
    context "as an admin" do
      before { sign_in admin }

      it "updates attributes and returns to the origin org edit page, scrolled to the row" do
        patch affiliation_path(affiliation, return_to: "organization", origin_id: organization.id),
              params: { affiliation: { title: "Lead facilitator" } }

        expect(affiliation.reload.title).to eq("Lead facilitator")
        expect(response).to redirect_to(edit_organization_path(organization, anchor: "affiliation_#{affiliation.id}"))
      end

      it "reassigns the person and returns to the origin person edit page" do
        other_person = create(:person)

        patch affiliation_path(affiliation, return_to: "person", origin_id: person.id),
              params: { affiliation: { person_id: other_person.id } }

        expect(affiliation.reload.person_id).to eq(other_person.id)
        expect(response).to redirect_to(edit_person_path(person, anchor: "affiliation_#{affiliation.id}"))
      end

      it "adds a comment authored by the current user" do
        expect {
          patch affiliation_path(affiliation, return_to: "organization", origin_id: organization.id),
                params: { affiliation: { comments_attributes: [ { body: "Left a note" } ] } }
        }.to change { affiliation.comments.count }.by(1)

        comment = affiliation.comments.first
        expect(comment.body).to eq("Left a note")
        expect(comment.created_by).to eq(admin)
      end

      it "links and unlinks the affiliation's registration through the picker" do
        registration = create(:event_registration, registrant: person)

        patch affiliation_path(affiliation, return_to: "organization", origin_id: organization.id),
              params: { affiliation: { event_registration_id: registration.id } }
        expect(affiliation.reload.event_registration_id).to eq(registration.id)

        patch affiliation_path(affiliation, return_to: "organization", origin_id: organization.id),
              params: { affiliation: { event_registration_id: "" } }
        expect(affiliation.reload.event_registration_id).to be_nil
      end

      it "assigns the organization address through the editor" do
        address = create(:address, addressable: organization)

        patch affiliation_path(affiliation, return_to: "organization", origin_id: organization.id),
              params: { affiliation: { organization_address_id: address.id } }

        expect(affiliation.reload.organization_address_id).to eq(address.id)
      end

      it "updates the FileMaker code" do
        patch affiliation_path(affiliation, return_to: "organization", origin_id: organization.id),
              params: { affiliation: { filemaker_code: "FM-123" } }

        expect(affiliation.reload.filemaker_code).to eq("FM-123")
      end
    end

    context "as a non-admin" do
      before { sign_in regular_user }

      it "does not update and redirects to root" do
        patch affiliation_path(affiliation), params: { affiliation: { title: "Changed" } }

        expect(affiliation.reload.title).to eq("Facilitator")
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "DELETE /affiliations/:id" do
    context "as an admin returning from the editor" do
      before { sign_in admin }

      it "destroys the affiliation and returns to the origin edit page" do
        expect {
          delete affiliation_path(affiliation, return_to: "organization", origin_id: organization.id)
        }.to change(Affiliation, :count).by(-1)

        expect(response).to redirect_to(edit_organization_path(organization, anchor: "affiliations"))
      end
    end

    context "as a non-admin" do
      before { sign_in regular_user }

      it "does not destroy and redirects to root" do
        expect {
          delete affiliation_path(affiliation, return_to: "organization", origin_id: organization.id)
        }.not_to change(Affiliation, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /affiliations/:id/end" do
    # The request runs in the user's (Pacific) zone while these assertions run in
    # the default UTC zone; freeze to midday UTC so both land on the same calendar
    # date and the today fallback doesn't drift by a day.
    before { travel_to Time.current.midday }

    context "as an admin" do
      before { sign_in admin }

      it "end-dates the affiliation and returns to the submission it came from" do
        submission = create(:form_submission, person: person)

        post end_affiliation_path(affiliation, end_date: "2026-08-14", form_submission_id: submission.id)

        expect(affiliation.reload.end_date).to eq(Date.new(2026, 8, 14))
        expect(affiliation.inactive).to be(true)
        expect(response).to redirect_to(form_submission_path(submission))
      end

      it "falls back to today and the person's edit page without params" do
        post end_affiliation_path(affiliation, end_date: "not-a-date")

        expect(affiliation.reload.end_date).to eq(Date.current)
        expect(response.location).to include(edit_person_path(person))
      end
    end

    context "as a non-admin" do
      before { sign_in regular_user }

      it "does not end the affiliation" do
        post end_affiliation_path(affiliation, end_date: "2026-08-14")

        expect(affiliation.reload.end_date).to be_nil
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
