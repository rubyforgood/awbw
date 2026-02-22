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
      expect(page).to have_button("Register") # register still visible
    end

    it "blocks guests from non-public events" do
      event.update!(publicly_visible: false)

      visit event_path(event)

      expect(page).to have_current_path(root_path)
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
      expect(page).to have_text("Join on Example_zoom")

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
    it "shows Edit for admin" do
      sign_in(admin)
      visit event_path(event)

      expect(page).to have_link("Edit", href: edit_event_path(event))
    end

    it "hides Edit for regular users" do
      sign_in(user)
      visit event_path(event)

      expect(page).not_to have_link("Edit")
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
        expect(page).not_to have_button("De-register")
        expect(page).not_to have_text("You are registered!")
      end
    end

    context "user registered" do
      before do
        create(:event_registration, event: event, registrant: user.person)
      end

      it "shows deregister button, badge, and calendar links" do
        sign_in(user)
        visit event_path(event)

        expect(page).to have_button("De-register")
        expect(page).to have_text("You are registered!")
        expect(page).to have_text("Google")
        expect(page).to have_text("Office 365")
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
      end

      it "shows 'Event ended' and hides registration buttons" do
        sign_in(user)
        visit event_path(event)

        expect(page).to have_text("Event ended")
        expect(page).not_to have_button("Register")
        expect(page).not_to have_button("De-register")
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
  # REGISTRATION BUTTON UPDATES VIA TURBO
  # --------------------------------------------------

  describe "registration button updates via Turbo", js: true do
    before { driven_by(:selenium_chrome_headless) }

    it "updates Register to De-register and shows badge without full page reload" do
      sign_in(user)
      visit event_path(event)

      expect(page).to have_button("Register")
      expect(page).not_to have_text("You are registered!")

      click_button "Register"

      # Turbo stream replaces the registration section; we stay on the event page
      expect(page).to have_current_path(event_path(event))
      expect(page).to have_button("De-register")
      expect(page).to have_text("You are registered!")
      expect(page).not_to have_button("Register")
    end

    it "updates De-register back to Register after de-registering" do
      create(:event_registration, event: event, registrant: user.person)

      sign_in(user)
      visit event_path(event)

      expect(page).to have_button("De-register")
      accept_confirm do
        click_button "De-register"
      end

      expect(page).to have_current_path(event_path(event))
      expect(page).to have_button("Register")
      expect(page).not_to have_button("De-register")
      expect(page).not_to have_text("You are registered!")
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

      encoded_url = CGI.escape(event_url(event))

      # Share buttons point to correct share endpoints with event URL
      linkedin = find("a[title='Share on LinkedIn']")
      expect(linkedin[:href]).to include("linkedin.com/sharing/share-offsite/")
      expect(linkedin[:href]).to include(encoded_url)

      facebook = find("a[title='Share on Facebook']")
      expect(facebook[:href]).to include("facebook.com/sharer/sharer.php")
      expect(facebook[:href]).to include(encoded_url)

      twitter = find("a[title='Share on X']")
      expect(twitter[:href]).to include("twitter.com/intent/tweet")
      expect(twitter[:href]).to include(encoded_url)

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
