require "rails_helper"

RSpec.describe "Event show page", type: :system do
  let(:user)  { create(:user, :with_person, time_zone: "Pacific Time (US & Canada)") }
  let(:admin) { create(:user, :with_person, :admin, time_zone: "Pacific Time (US & Canada)") }

  let(:event) do
    create(
      :event,
      :published,
      :publicly_visible,
      title: "My Event",
      rhino_description: "A wonderful event",
      start_date: 2.days.from_now.change(hour: 10), # UTC
      end_date:   2.days.from_now.change(hour: 12), # UTC
      cost: 10.99,
      location: create(:location),
      videoconference_url: "https://www.example_zoom.com/123",
      registration_close_date: 5.days.from_now
    )
  end

  before { driven_by(:rack_test) }

  # --------------------------------------------------
  # GUEST ACCESS (public events)
  # --------------------------------------------------

  describe "guest access" do
    it "allows guests to view public events" do
      visit event_path(event)

      expect(page).to have_text("My Event")
    end

    it "blocks guests from non-public events" do
      event.update!(publicly_visible: false)

      visit event_path(event)

      expect(page).to have_current_path(root_path)
    end

    context "when event has a public registration form" do
      before do
        create(:form, name: "Short Event Registration")
        event.update!(public_registration_enabled: true)
      end

      it "shows register link to public registration" do
        visit event_path(event)

        expect(page).to have_link("Register", href: new_event_registration_form_path(event))
      end
    end

    context "when event has no public registration form" do
      it "does not show a register button" do
        visit event_path(event)

        expect(page).not_to have_button("Register")
        expect(page).not_to have_link("Register")
      end
    end

    context "when event has public_registration_enabled but no form" do
      before do
        event.update!(public_registration_enabled: true)
        event.event_forms.destroy_all
      end

      it "does not show a register button" do
        visit event_path(event)

        expect(page).not_to have_button("Register")
        expect(page).not_to have_link("Register")
      end
    end
  end

  # --------------------------------------------------
  # BASIC RENDERING (decorator + view)
  # --------------------------------------------------

  describe "basic rendering" do
    it "shows core event info" do
      sign_in(user)
      visit event_path(event)

      expect(page).to have_text("My Event")
      expect(page).to have_text("A wonderful event")
      expect(page).to have_text(event.location.name)
      expect(page).to have_text("Virtual event")

      # Decorator
      expect(page).to have_text("Cost: $10.99")
      expect(page).to have_text("2") # Pacific Time
      expect(page).to have_text("4") # Pacific Time

      # Bookmark UI always present
      expect(page).to have_css("span.inline-block")
    end
  end

  # --------------------------------------------------
  # ADMIN CONTROLS
  # --------------------------------------------------

  describe "admin buttons" do
    it "shows admin controls for admin" do
      sign_in(admin)
      visit event_path(event)

      expect(page).to have_link("Dashboard", href: dashboard_event_path(event))
      expect(page).to have_link("Registrants", href: registrants_event_path(event))
    end

    it "hides admin controls for regular users" do
      sign_in(user)
      visit event_path(event)

      expect(page).not_to have_link("Dashboard")
      expect(page).not_to have_link("Registrants")
    end
  end

  # --------------------------------------------------
  # REGISTRATION STATES
  # --------------------------------------------------

  describe "registration states" do
    context "user not registered" do
      it "shows Register button" do
        sign_in(user)
        visit event_path(event)

        expect(page).to have_button("Register")
        expect(page).not_to have_text("View your registration")
      end
    end

    context "user registered" do
      before do
        create(:event_registration, event: event, registrant: user.person)
      end

      it "shows registration link and calendar links" do
        sign_in(user)
        visit event_path(event)

        expect(page).to have_text("View ticket")
        expect(page).to have_text("Add to Your Calendar")
        expect(page).to have_text("Google")
        expect(page).to have_text("Office 365")
        expect(page).not_to have_button("Register")
      end
    end

    context "registration closed" do
      before do
        event.update!(registration_close_date: 1.day.ago)
      end

      it "shows closed indicator" do
        sign_in(user)
        visit event_path(event)

        expect(page).to have_text("Registration closed")
        expect(page).not_to have_button("Register")
      end
    end

    context "event ended" do
      before do
        event.update!(end_date: 1.day.ago)
        create(:event_registration, event: event, registrant: user.person, status: "registered")
      end

      it "shows 'Event ended' and hides registration buttons" do
        sign_in(user)
        visit event_path(event)

        expect(page).to have_text("Event ended")
        expect(page).not_to have_button("Register")
        expect(page).not_to have_button("De-register")
      end

      it "shows 'View ticket' for registered user" do
        sign_in(user)
        visit event_path(event)

        expect(page).to have_text("Event ended")
        expect(page).to have_text("View ticket")
      end

      it "hides calendar links" do
        sign_in(user)
        visit event_path(event)

        expect(page).not_to have_text("Add to Your Calendar")
      end

      it "blocks unregistered users" do
        other_user = create(:user, :with_person)
        sign_in(other_user)
        visit event_path(event)

        expect(page).to have_current_path(root_path)
      end

      it "allows admin to view" do
        sign_in(admin)
        visit event_path(event)

        expect(page).to have_text("Event ended")
        expect(page).to have_text("My Event")
      end
    end

    context "guest with reg slug param" do
      let!(:registration) { create(:event_registration, event: event, registrant: user.person) }

      it "shows 'View ticket' badge and calendar links" do
        visit event_path(event, reg: registration.slug)

        expect(page).to have_text("View ticket")
        expect(page).to have_text("Add to Your Calendar")
        expect(page).not_to have_button("Register")
      end

      it "does not show badge with invalid slug" do
        visit event_path(event, reg: "bogus-slug")

        expect(page).not_to have_text("View your registration")
      end

      it "does not show badge with slug from a different event" do
        other_event = create(:event, :published, :publicly_visible)
        other_registration = create(:event_registration, event: other_event, registrant: user.person)

        visit event_path(event, reg: other_registration.slug)

        expect(page).not_to have_text("View your registration")
      end
    end

    context "guest with cancelled registration slug" do
      let!(:registration) { create(:event_registration, event: event, registrant: user.person, status: "cancelled") }

      it "does not show 'View your registration' link" do
        visit event_path(event, reg: registration.slug)

        expect(page).not_to have_text("View your registration")
      end

      it "shows 'Register again' button" do
        visit event_path(event, reg: registration.slug)

        expect(page).to have_button("Register again")
      end

      it "does not show 'Register again' when registration is closed" do
        event.update!(registration_close_date: 1.day.ago)

        visit event_path(event, reg: registration.slug)

        expect(page).not_to have_button("Register again")
        expect(page).to have_text("Registration closed")
      end
    end

    context "unpublished event with future registration date" do
      before do
        event.update!(published: false, publicly_visible: false)
      end

      it "shows 'Not published' instead of 'Registration closed' for admins" do
        sign_in(admin)
        visit event_path(event)

        expect(page).to have_text("Not published")
        expect(page).not_to have_text("Registration closed")
        expect(page).not_to have_button("Register")
      end
    end
  end

  # --------------------------------------------------
  # VIDEOCONFERENCE LINK
  # --------------------------------------------------

  describe "virtual event label" do
    it "shows 'Virtual event' label by default" do
      sign_in(user)
      visit event_path(event)

      expect(page).to have_text("Virtual event")
    end

    it "shows custom label text when set" do
      event.update!(videoconference_label: "Join us online")

      sign_in(user)
      visit event_path(event)

      expect(page).to have_text("Join us online")
      expect(page).not_to have_text("Virtual event")
    end

    it "hides label when autoshow_videoconference_label is false" do
      event.update!(autoshow_videoconference_label: false)

      sign_in(user)
      visit event_path(event)

      expect(page).not_to have_text("Virtual event")
    end

    it "hides label when videoconference_label is blank" do
      event.update!(videoconference_label: "")

      sign_in(user)
      visit event_path(event)

      expect(page).not_to have_text("Virtual event")
    end
  end

  describe "videoconference link" do
    context "user not registered" do
      it "does not show the join link" do
        sign_in(user)
        visit event_path(event)

        expect(page).not_to have_link("Join on Example_zoom")
      end
    end

    context "user registered for a free event" do
      let(:free_event) do
        create(:event, :published, :publicly_visible,
               title: "Free Event",
               cost_cents: 0,
               videoconference_url: "https://www.zoom.us/123",
               start_date: 2.days.from_now,
               end_date: 2.days.from_now + 2.hours)
      end

      before { create(:event_registration, event: free_event, registrant: user.person) }

      it "shows linked 'Join on Zoom'" do
        sign_in(user)
        visit event_path(free_event)

        expect(page).to have_link("Join on Zoom", href: "https://www.zoom.us/123")
      end
    end

    context "user registered for a paid event but not paid" do
      before { create(:event_registration, event: event, registrant: user.person) }

      it "does not show the join link" do
        sign_in(user)
        visit event_path(event)

        expect(page).not_to have_link("Join on Example_zoom")
      end
    end

    context "user registered and paid for a paid event" do
      before do
        registration = create(:event_registration, event: event, registrant: user.person)
        payment = create(:payment, person: user.person, amount_cents: event.cost_cents, amount_cents_remaining: nil)
        create(:allocation, source: payment, allocatable: registration, amount: event.cost_cents)
      end

      it "shows linked 'Join on' domain" do
        sign_in(user)
        visit event_path(event)

        expect(page).to have_link("Join on Example_zoom", href: "https://www.example_zoom.com/123")
      end
    end

    context "user registration is cancelled" do
      before do
        create(:event_registration, event: event, registrant: user.person, status: "cancelled")
      end

      it "does not show the join link" do
        sign_in(user)
        visit event_path(event)

        expect(page).not_to have_link("Join on Example_zoom")
      end
    end

    context "user has full scholarship with tasks completed" do
      before do
        registration = create(:event_registration, event: event, registrant: user.person)
        scholarship = create(:scholarship, tasks_completed: true, amount_cents: event.cost_cents)
        create(:allocation, source: scholarship, allocatable: registration, amount: event.cost_cents)
      end

      it "shows linked 'Join on' domain" do
        sign_in(user)
        visit event_path(event)

        expect(page).to have_link("Join on Example_zoom")
      end
    end

    context "user has scholarship but tasks not completed" do
      before do
        registration = create(:event_registration, event: event, registrant: user.person)
        scholarship = create(:scholarship, tasks_completed: false, amount_cents: event.cost_cents)
        create(:allocation, source: scholarship, allocatable: registration, amount: 0)
      end

      it "does not show the join link" do
        sign_in(user)
        visit event_path(event)

        expect(page).not_to have_link("Join on Example_zoom")
      end
    end

    context "autoshow_videoconference_link is false" do
      before do
        event.update!(autoshow_videoconference_link: false)
        registration = create(:event_registration, event: event, registrant: user.person)
        payment = create(:payment, person: user.person, amount_cents: event.cost_cents, amount_cents_remaining: nil)
        create(:allocation, source: payment, allocatable: registration, amount: event.cost_cents)
      end

      it "hides the join link even when joinable" do
        sign_in(user)
        visit event_path(event)

        expect(page).to have_text("Virtual event")
        expect(page).not_to have_link("Join on Example_zoom")
      end
    end
  end

  # --------------------------------------------------
  # REGISTRATION BUTTON UPDATES VIA TURBO
  # --------------------------------------------------

  describe "registration button updates via Turbo", js: true do
    before do
      driven_by(:selenium_chrome_headless)
      event.update!(cost_cents: 0)
    end

    it "updates Register to show registration link without full page reload" do
      sign_in(user)
      visit event_path(event)

      expect(page).to have_button("Register")
      expect(page).not_to have_text("View ticket")

      click_button "Register"

      # Turbo stream replaces the registration section; we stay on the event page
      expect(page).to have_current_path(event_path(event))
      expect(page).not_to have_button("Register")

      # "View ticket" is a clickable link to the registration show page
      expect(page).to have_link("View ticket")
      registration = EventRegistration.last
      expect(page).to have_link("View ticket", href: registration_ticket_path(registration.slug))
    end
  end

  # --------------------------------------------------
  # REGISTRATION CLOSE DATE SECTION
  # --------------------------------------------------

  describe "registration close date display" do
    it "renders when present" do
      sign_in(user)
      visit event_path(event)

      expect(page).to have_text("Registration closes")
    end

    it "does not render when nil" do
      event.update!(registration_close_date: nil)

      sign_in(user)
      visit event_path(event)

      expect(page).not_to have_text("Registration closes")
    end
  end

  # --------------------------------------------------
  # ASSETS
  # --------------------------------------------------

  describe "images" do
    context "with primary image" do
      it "renders hero image" do
        event = create(:event, :with_primary_asset)

        sign_in(user)
        visit event_path(event)

        expect(page).to have_css("img")
      end
    end

    context "with gallery images" do
      it "renders thumbnails" do
        event = create(:event, :with_gallery_assets)

        sign_in(user)
        visit event_path(event)

        expect(page).to have_css("img", minimum: 2)
      end
    end
  end

  # --------------------------------------------------
  # SOCIAL SHARE SIDEBAR
  # --------------------------------------------------

  describe "social share sidebar" do
    it "renders share links with correct URLs" do
      sign_in(user)
      visit event_path(event)

      encoded_path = CGI.escape("/events/#{event.id}")

      # Share buttons point to correct share endpoints with event URL
      linkedin = find("a[title='Share on LinkedIn']")
      expect(linkedin[:href]).to include("linkedin.com/sharing/share-offsite/")
      expect(linkedin[:href]).to include(encoded_path)

      facebook = find("a[title='Share on Facebook']")
      expect(facebook[:href]).to include("facebook.com/sharer/sharer.php")
      expect(facebook[:href]).to include(encoded_path)

      twitter = find("a[title='Share on X']")
      expect(twitter[:href]).to include("twitter.com/intent/tweet")
      expect(twitter[:href]).to include(encoded_path)

      # Profile links
      instagram = find("a[title='Follow on Instagram']")
      expect(instagram[:href]).to include("instagram.com/awbworg")

      youtube = find("a[title='Subscribe on YouTube']")
      expect(youtube[:href]).to include("youtube.com/@awbworg")

      # Print button
      expect(page).to have_css("button[title='Print this page']")
    end

    it "renders share links for guests on public events" do
      visit event_path(event)

      expect(page).to have_css("a[title='Share on Facebook']")
      expect(page).to have_css("a[title='Share on LinkedIn']")
      expect(page).to have_css("a[title='Share on X']")
      expect(page).to have_css("button[title='Print this page']")
    end
  end

  # --------------------------------------------------
  # POLICY / VISIBILITY EDGE CASES
  # --------------------------------------------------

  describe "visibility rules" do
    it "hides inactive events from non-admins" do
      event.update!(published: false, publicly_visible: false)

      sign_in(user)
      visit event_path(event)

      expect(page).to have_current_path(root_path)
    end

    it "allows admins to view inactive events" do
      event.update!(published: false, publicly_visible: false)

      sign_in(admin)
      visit event_path(event)

      expect(page).to have_text("My Event")
    end
  end
end
