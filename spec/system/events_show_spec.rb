require "rails_helper"

RSpec.describe "Event show page", type: :system do
  let(:user) { create(:user) }
  let(:super_user) { create(:user, super_user: true) }
  let(:event) { create(:event, title: "My Event").decorate }

  before do
    driven_by(:rack_test)
  end

  describe "basic rendering" do
    it "shows title, description, dates, and bookmark button" do
      sign_in(user)
      visit event_path(event)

      # Title (uses title_with_badges)
      expect(page).to have_css("div.my-3", text: "My Event")

      # Times block exists
      expect(page).to have_text("Start:")
      expect(page).to have_text("End:")

      # Day + month appear (stable, user-facing)
      expect(page).to have_text(event.start_date.strftime("%b"))
      expect(page).to have_text(event.end_date.strftime("%b"))

      # Description
      expect(page).to have_css("p.text-gray-900", text: event.description)

      # Bookmark button is always shown
      expect(page).to have_css("span.inline-block")
    end
  end

  describe "super user buttons" do
    it "shows Edit button for super users only" do
      sign_in(super_user)
      visit event_path(event)

      expect(page).to have_link("Edit", href: edit_event_path(event))
    end

    it "does NOT show Edit button for regular users" do
      sign_in(user)
      visit event_path(event)

      expect(page).not_to have_link("Edit")
    end
  end

  describe "registration states" do
    context "when not registered" do
      it "shows Register button" do
        allow(event).to receive(:registerable?).and_return(true)

        sign_in(user)
        visit event_path(event)

        expect(page).to have_button("Register")
        expect(page).not_to have_button("De-register")
        expect(page).not_to have_text("You are registered!")
      end
    end

    context "when registered" do
      before do
        create(:event_registration, event: event, registrant: user)
      end

      it "shows De-register button + registered badge + calendar links" do
        sign_in(user)
        visit event_path(event)

        expect(page).to have_button("De-register")
        expect(page).to have_text("You are registered!")
        expect(page).to have_text("Office 365")
      end
    end

    context "when registration closed" do
      it "shows closed indicator" do
        allow(event).to receive(:registerable?).and_return(false)
        event.registration_close_date = 1.day.ago
        event.save!

        sign_in(user)
        visit event_path(event)

        expect(page).to have_text("Registration closed")
        expect(page).not_to have_button("Register")
      end
    end
  end

  describe "registration close date" do
    it "shows formatted registration close date if present" do
      event.update!(registration_close_date: 12.days.from_now.change(hour: 12, min: 0, sec: 0))

      sign_in(user)
      visit event_path(event)

      expect(page).to have_text("Registration Close Date")
      expect(page).to have_text(12.days.from_now.strftime("%B %-d"))
      expect(page).to have_text("12:00 pm")
    end

    it "does NOT show section when registration_close_date is nil" do
      event.update!(registration_close_date: nil)

      sign_in(user)
      visit event_path(event)

      expect(page).not_to have_text("Registration Close Date")
    end
  end

  describe "images" do
    context "with main image" do
      it "displays the hero image" do
        event.primary_asset = create(:primary_asset, :with_file, owner: event)
        event.save!

        sign_in(user)
        visit event_path(event)

        expect(page).to have_css(".hero-item img", count: 1)
      end
    end

    context "with gallery images" do
      it "shows each gallery thumbnail" do
        2.times do
          event.object.gallery_assets << create(:gallery_assets, :with_file, owner: event.object)
        end
        sign_in(user)
        visit event_path(event.object)

        expect(page).to have_css(".gallery-item img", count: 2)
      end
    end
  end

  describe "layout integrity" do
    it "keeps description full width (outside grid columns)" do
      sign_in(user)
      visit event_path(event)

      # description lives after the grid — ensure CSS class is present
      expect(page).to have_css("div.mt-6.md\\:col-span-5")
    end

    it "loads inside the blue outer container" do
      sign_in(user)
      visit event_path(event)

      expect(page).to have_css("div.bg-blue-50") # <%= DomainTheme.bg_class_for(:events) %>
      expect(page).to have_css("div.bg-white.rounded-lg.shadow.p-8")
    end
  end
end
