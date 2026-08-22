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

      it "surfaces a linked registration with the org-linking warning" do
        registration = create(:event_registration)
        affiliation.update_column(:event_registration_id, registration.id)

        get edit_affiliation_path(affiliation)

        expect(response.body).to include("Linked to a registration")
        expect(response.body).to include(link_organization_event_registration_path(registration))
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

      it "assigns the organization address through the editor" do
        address = create(:address, addressable: organization)

        patch affiliation_path(affiliation, return_to: "organization", origin_id: organization.id),
              params: { affiliation: { organization_address_id: address.id } }

        expect(affiliation.reload.organization_address_id).to eq(address.id)
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
end
