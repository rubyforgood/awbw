require "rails_helper"

RSpec.describe "People send_form_link", type: :request do
  let(:admin) { create(:user, :admin) }
  # No portal user, so preferred_email is the person's own email.
  let(:person) { create(:person, user: nil, email: "fac@example.com") }
  let(:form) do
    create(:form, name: "Collaboration agreement (job change)", purpose: "job_change",
                  slug: "collab-job-change", published: true)
  end

  describe "POST /people/:id/send_form_link" do
    context "as an admin" do
      before { sign_in admin }

      it "records a form_link_request notification carrying the public link and redirects back" do
        expect {
          post send_form_link_person_path(person, form_id: form.id)
        }.to change(Notification.where(kind: "form_link_request"), :count).by(1)

        notification = Notification.where(kind: "form_link_request").last
        expect(notification.noticeable).to eq(person)
        expect(notification.recipient_email).to eq("fac@example.com")
        expect(notification.custom_subject).to include(form.display_name)
        expect(notification.custom_message).to include("/f/collab-job-change")
        expect(notification.sender).to eq(admin)
        expect(response).to redirect_to(edit_person_path(person, anchor: "agreement-links"))
      end

      it "refuses when the form has no public link" do
        form.update!(published: false, slug: nil)

        expect {
          post send_form_link_person_path(person, form_id: form.id)
        }.not_to change(Notification, :count)

        expect(flash[:alert]).to include("no public link")
      end

      it "refuses when the person has no email" do
        emailless = create(:person, user: nil, email: nil)

        expect {
          post send_form_link_person_path(emailless, form_id: form.id)
        }.not_to change(Notification, :count)

        expect(flash[:alert]).to include("no email")
      end

      it "404s for a form without an agreement purpose" do
        plain = create(:form, slug: "plain", published: true)

        post send_form_link_person_path(person, form_id: plain.id)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "as a non-admin" do
      before { sign_in create(:user) }

      it "does not send" do
        expect {
          post send_form_link_person_path(person, form_id: form.id)
        }.not_to change(Notification, :count)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "the agreement links panel on the person edit page" do
    before { sign_in admin }

    it "lists each purposed form with its send button and last-sent info" do
      form
      Notification.create!(kind: "form_link_request", noticeable: person, recipient_role: "person",
                           recipient_email: "fac@example.com", notification_type: 0,
                           custom_subject: "Link to complete #{form.display_name}",
                           custom_message: "http://example.com/f/collab-job-change", sender: admin)

      get edit_person_path(person)

      expect(response.body).to include("Agreement form links")
      expect(response.body).to include("Job change agreement")
      expect(response.body).to include(send_form_link_person_path(person, form_id: form.id))
      expect(response.body).to include("Last sent")
    end

    it "omits the panel when no purposed forms exist" do
      get edit_person_path(person)

      expect(response.body).not_to include("Agreement form links")
    end
  end
end
