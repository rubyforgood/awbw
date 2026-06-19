require "rails_helper"

RSpec.describe "Event registration show page", type: :system do
  let(:user) { create(:user, :with_person, time_zone: "Pacific Time (US & Canada)") }

  let(:event) do
    create(
      :event,
      :published,
      title: "My Event",
      start_date: 2.days.from_now.change(hour: 10),
      end_date: 2.days.from_now.change(hour: 12)
    )
  end

  let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

  before { driven_by(:rack_test) }

  describe "back to event link" do
    it "shows a back link to the event page with reg param" do
      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_link("Back to event", href: event_path(event, reg: registration.slug))
    end
  end

  describe "event title link" do
    it "links the event title back to the event page with reg param" do
      sign_in(user)
      visit registration_ticket_path(registration.slug)

      within("h2") do
        expect(page).to have_link(event.title, href: event_path(event, reg: registration.slug))
      end
    end
  end

  describe "calendar links" do
    it "shows Add to your calendar header and calendar links" do
      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_text("Add to your calendar")
      expect(page).to have_link("Google")
      expect(page).to have_link("Office 365")
    end
  end

  describe "payment due" do
    it "shows the payment card with the amount due and a pay button for an active registration with a balance" do
      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_text("Make your payment")
      expect(page).to have_text("due")
      expect(page).to have_button("Pay with Credit Card")
    end

    it "hides the pay button when the registrant chose to pay by check" do
      registration.update!(payment_method: "Check")

      sign_in(user)
      visit registration_ticket_path(registration.slug)

      # The balance callout still shows (a check payer still owes), but the
      # credit-card action button is replaced by the mailed-check note.
      expect(page).to have_text("Make your payment")
      expect(page).to have_no_button("Pay with Credit Card")
      expect(page).to have_text("Pay by mailed check")
    end
  end

  describe "before-you-attend call-out" do
    it "links to the details page using the event's label when details are present" do
      event.update!(event_details_label: "Art supplies", event_details: "<p>Bring scissors</p>")

      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_link("Art supplies", href: details_event_path(event, reg: registration.slug))
    end

    it "is hidden when no details are set" do
      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_no_link(href: details_event_path(event, reg: registration.slug))
    end
  end

  describe "registration ticket callouts" do
    it "shows a call-out linking to the callout's detail page" do
      callout = create(:registration_ticket_callout, event: event,
        title: "Parking", subtitle: "Where to park", description: "<p>North lot</p>")

      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_link("Parking",
        href: event_registration_ticket_callout_path(event, callout, reg: registration.slug))
      expect(page).to have_text("Where to park")
    end

    it "hides a payment-gated callout until the registration is paid in full" do
      gated_callout = create(:registration_ticket_callout, :payment_access_gated, event: event, title: "Your workbook")

      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_no_link("Your workbook")

      create(:allocation, source: create(:payment), allocatable: registration, amount: event.cost_cents)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_link("Your workbook",
        href: event_registration_ticket_callout_path(event, gated_callout, reg: registration.slug))
    end
  end

  describe "view registration form link" do
    it "links to form show with slug param" do
      FormBuilderService.new(
        name: "Extended Event Registration",
        sections: %i[person_identifier person_contact_info person_background professional_info marketing scholarship payment consent]
      ).call.tap { |form| EventForm.create!(event: event, form: form, role: "registration") }
      form = event.registration_form
      form.form_submissions.create!(person: user.person)

      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_link("View your form responses",
        href: event_public_registration_path(event, reg: registration.slug))
    end
  end

  describe "action links" do
    it "shows resend and cancel for active registration" do
      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_button("Resend confirmation email")
      expect(page).to have_button("Cancel registration")
    end

    it "hides resend and cancel for cancelled registration" do
      registration.update!(status: "cancelled")

      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).not_to have_button("Resend confirmation email")
      expect(page).not_to have_button("Cancel registration")
    end
  end

  describe "cancelled registration" do
    before { registration.update!(status: "cancelled") }

    it "shows Registration cancelled badge and Register again button" do
      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_text("Registration cancelled")
      expect(page).to have_button("Register again")
    end

    it "does not show Register again when registration is closed" do
      event.update!(registration_close_date: 1.day.ago)

      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).to have_text("Registration cancelled")
      expect(page).not_to have_button("Register again")
    end

    it "does not show the payment-due badge or pay button" do
      sign_in(user)
      visit registration_ticket_path(registration.slug)

      expect(page).not_to have_text("payment is due")
      expect(page).not_to have_button("Pay with Credit Card")
    end
  end

  describe "guest access" do
    it "allows guests to view the ticket via slug" do
      visit registration_ticket_path(registration.slug)

      expect(page).to have_text("Registration ticket")
      expect(page).to have_text(registration.registrant.full_name)
    end
  end
end
