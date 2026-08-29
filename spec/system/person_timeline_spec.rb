# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Person timeline", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, first_name: "Amy", last_name: "User") }

  before do
    sign_in admin
    Current.user = admin
  end

  after do
    Current.reset
  end

  def timeline
    element = find("#person_timeline_section", wait: 20)
    page.execute_script("arguments[0].scrollIntoView({ block: 'center' })", element)
    element
  end

  # Seeds every subject type with a created event, updates on the types whose
  # change chips are worth asserting, and destroys a couple of throwaways so the
  # "removed ... from" context renders. The person's own created event lands
  # first; the whole matrix fits on page one (under per_page 25).
  def seed_full_timeline
    category = create(:category, name: "Kids")
    category_throwaway = create(:category, name: "Grown-ups")
    org = create(:organization, name: "Arts Org")
    org_throwaway = create(:organization, name: "Removed Org")
    form = create(:form, name: "Demo Form")
    event = create(:event, title: "Demo Training")
    tag_a = create(:staff_tag, name: "Roster 1")
    tag_b = create(:staff_tag, name: "Roster 2")

    address = create(:address, addressable: person, city: "Simple City", state: "CA",
                               zip_code: "90001", locality: "LA City")
    address.update!(city: "Other City")

    contact = create(:contact_method, contactable: person, kind: "phone", value: "555-010-1010")
    contact.update!(value: "555-020-2020")

    license = create(:professional_license, person: person, kind: "LMFT", number: "LIC-1")
    license.update!(kind: "LCSW")

    create(:categorizable_item, categorizable: person, category: category)
    create(:sectorable_item, sectorable: person, sector: create(:sector, name: "Arts and Culture"))

    tagging = StaffTagging.create!(staff_taggable: person, staff_tag: tag_a)
    tagging.update!(staff_tag: tag_b)

    create(:affiliation, person: person, organization: org)
    throwaway_affiliation = create(:affiliation, person: person, organization: org_throwaway)
    throwaway_affiliation.destroy!

    create(:form_submission, person: person, form: form)
    create(:scholarship, recipient: person, amount_cents: 100_00)

    registration = create(:event_registration, event: event, registrant: person)
    create(:continuing_education_registration, event_registration: registration,
                                               professional_license: license)

    create(:comment, commentable: person, body: "A note")
    create(:notification, noticeable: person)

    throwaway_category = create(:categorizable_item, categorizable: person, category: category_throwaway)
    throwaway_category.destroy!
  end

  scenario "shows every subject type and all action types on the person timeline" do
    seed_full_timeline

    visit edit_person_path(person)

    expect(timeline).to have_content(admin.full_name)
    expect(timeline).to have_content("created")
    expect(timeline).to have_content("updated")
    expect(timeline).to have_content("removed")

    expect(timeline).to have_content("category 'Kids' on Amy User")
    expect(timeline).to have_content("sector 'Arts and Culture' on Amy User")
    expect(timeline).to have_content("Address on Amy User")
    expect(timeline).to have_content("Phone on Amy User")
    expect(timeline).to have_content("Professional license on Amy User")
    expect(timeline).to have_content("Tag: Roster")
    expect(timeline).to have_link("Affiliation: Amy User at Arts Org")
    expect(timeline).to have_content("Form Submission: Demo Form")
    expect(timeline).to have_content("Scholarship: Amy User")
    expect(timeline).to have_content("Event Registration: Demo Training")
    expect(timeline).to have_content("CE Registration: Amy User")
    expect(timeline).to have_content("Comment on Amy User")
    expect(timeline).to have_content("Autoemail Outgoing")

    expect(timeline).to have_content("LCSW")
    expect(timeline).to have_content("555-020-2020")
    expect(timeline).to have_content("Other City")

    expect(timeline).to have_css("span", text: "category 'Grown-ups' from Amy User")
    expect(timeline).to have_css("span", text: "Affiliation: Amy User at Removed Org")
    expect(timeline).not_to have_link("category 'Grown-ups' from Amy User")
    expect(timeline).not_to have_link("Affiliation: Amy User at Removed Org")
  end

  scenario "shows the empty state when no activity is recorded" do
    # Creating via the factory already records the person's own "created" event;
    # clear it to emulate a record that predates the timeline feature.
    person.timeline_events.destroy_all

    visit edit_person_path(person)

    expect(timeline).to have_content("No activity recorded yet.")
  end
end
