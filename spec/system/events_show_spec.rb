require "rails_helper"

RSpec.describe "Event show page", type: :system do
  let(:user)  { create(:user) }
  let(:admin) { create(:user, :admin) }

  let(:event) do
    create(
      :event,
      title: "My Event",
      rhino_description: "A wonderful event",
      publicly_visible: true,
      published: true,
      start_date: 2.days.from_now.change(hour: 10),
      end_date:   2.days.from_now.change(hour: 12),
      cost: 10.99,
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

      # Decorator
      expect(page).to have_text("Cost: $10.99")
      expect(page).to have_text("10")
      expect(page).to have_text("12")

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
        create(:event_registration, event: event, registrant: user)
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
  end

  # --------------------------------------------------
  # REGISTRATION CLOSE DATE SECTION
  # --------------------------------------------------

  describe "registration close date display" do
    it "renders when present" do
      sign_in(user)
      visit event_path(event)

      expect(page).to have_text("Registration Close Date")
    end

    it "does not render when nil" do
      event.update!(registration_close_date: nil)

      sign_in(user)
      visit event_path(event)

      expect(page).not_to have_text("Registration Close Date")
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
