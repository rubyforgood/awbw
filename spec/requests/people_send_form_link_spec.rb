require "rails_helper"

RSpec.describe "People send_form_link", type: :request do
  let(:admin) { create(:user, :admin) }
  # No portal user, so preferred_email is the person's own email.
  let(:person) { create(:person, user: nil, email: "fac@example.com") }
  let(:form) do
    create(:form, name: "Collaboration agreement (new job)", role: "new_job",
                  slug: "collab-new-job", published: true)
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
        expect(notification.custom_message).to include("/f/collab-new-job")
        expect(notification.sender).to eq(admin)
        expect(response).to redirect_to(edit_person_path(person, agreement_links: 1, anchor: "agreement-links"))
      end

      it "404s for a form that isn't publicly fillable" do
        form.update!(published: false, slug: nil)

        expect {
          post send_form_link_person_path(person, form_id: form.id)
        }.not_to change(Notification, :count)

        expect(response).to have_http_status(:not_found)
      end

      it "refuses when the person has no email" do
        emailless = create(:person, user: nil, email: nil)

        expect {
          post send_form_link_person_path(emailless, form_id: form.id)
        }.not_to change(Notification, :count)

        expect(flash[:alert]).to include("no email")
      end

      it "sends an upcoming facilitator training's public registration form link" do
        training = create(:event, :published, facilitator_training: true, on_demand: false,
                          title: "Facilitator Training", start_date: 2.months.from_now)

        expect {
          post send_form_link_person_path(person, event_id: training.id)
        }.to change(Notification.where(kind: "form_link_request"), :count).by(1)

        notification = Notification.where(kind: "form_link_request").last
        expect(notification.custom_subject).to include("Facilitator Training", "registration")
        expect(notification.custom_message).to include(new_event_public_registration_path(training))
      end

      it "404s for an event that isn't a published facilitator training" do
        plain_event = create(:event, :published, facilitator_training: false)

        post send_form_link_person_path(person, event_id: plain_event.id)

        expect(response).to have_http_status(:not_found)
      end

      it "404s for a form without an agreement role" do
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

    it "lists each agreement form with its send button and how many times it has been sent" do
      form
      2.times do
        Notification.create!(kind: "form_link_request", noticeable: person, recipient_role: "person",
                             recipient_email: "fac@example.com", notification_type: 0,
                             custom_subject: "Link to complete #{form.display_name}",
                             custom_message: "http://example.com/f/collab-new-job", sender: admin)
      end

      get edit_person_path(person)

      expect(response.body).to include("Email form links")
      expect(response.body).to include("New job")
      expect(response.body).to include(send_form_link_person_path(person, form_id: form.id))
      expect(response.body).to include("Sent 2 times")
    end

    it "nests the on-demand training and upcoming scheduled trainings under the Registration group" do
      on_demand_form = create(:form, name: "Collaboration agreement (on-demand)", role: "registration",
                              slug: "collab-on-demand", published: true)
      on_demand_event = create(:event, :published, facilitator_training: true, on_demand: true,
                               title: "On-Demand Training", start_date: 2.months.ago)
      soon = create(:event, :published, facilitator_training: true, on_demand: false,
                    title: "Spring Training", start_date: 3.months.from_now)
      create(:event, :published, facilitator_training: true, on_demand: false,
             title: "Distant Training", start_date: 14.months.from_now)

      get edit_person_path(person)

      # The on-demand row is the current on-demand training's registration form,
      # not the standalone /f/ fallback form.
      expect(response.body).to include("On-Demand Training")
      expect(response.body).to include(send_form_link_person_path(person, event_id: on_demand_event.id))
      expect(response.body).not_to include(send_form_link_person_path(person, form_id: on_demand_form.id))
      expect(response.body).to include("Spring Training")
      expect(response.body).to include(send_form_link_person_path(person, event_id: soon.id))
      expect(response.body).not_to include("Distant Training")
    end

    it "says never sent for a form this person has not been emailed" do
      form

      get edit_person_path(person)

      expect(response.body).to include("Never sent")
    end

    it "collapses the panel by default and reopens it after a send" do
      form

      get edit_person_path(person)
      expect(response.body).to match(/<details id="agreement-links"[^>]*>\s*<summary/)

      get edit_person_path(person, agreement_links: 1)
      expect(response.body).to include("open")
      expect(response.body).to match(/<details id="agreement-links"[^>]*open/)
    end

    it "omits the panel when no agreement forms exist" do
      get edit_person_path(person)

      expect(response.body).not_to include("Email form links")
    end
  end
end
