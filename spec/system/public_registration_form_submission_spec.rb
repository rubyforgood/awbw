require "rails_helper"

# Exercises the three public, seed-shaped forms end to end — registration, the
# scholarship application appended to it, and bulk payment — each both while
# logged out ("incognito") and while logged in, asserting every submitted answer
# (and its registration / person side effects) is persisted. The forms are built
# with FormBuilderService using the same sections + magic CE / "Additional forms"
# questions the dev seeds attach, so the DOM matches what registrants really see.
RSpec.describe "Public form submissions", type: :system do
  let(:event) do
    create(:event, :published, :publicly_visible,
           title: "AWBW Facilitator Training",
           cost_cents: 150_000,
           start_date: 10.days.from_now.change(hour: 9),
           end_date: 11.days.from_now.change(hour: 16),
           registration_close_date: 5.days.from_now)
  end

  let(:registration_form) { build_registration_form }
  let(:continuing_education_form) { build_continuing_education_form }
  let(:scholarship_form) do
    FormBuilderService.new(name: "Scholarship Application", sections: %i[scholarship], role: "scholarship").call
  end
  let(:bulk_payment_form) do
    FormBuilderService.new(name: "Bulk Payment", sections: %i[bulk_payment], role: "bulk_payment").call
  end

  # Published Sectors + AgeRange categories so the dynamic sector / age fields
  # render real, selectable options (they source from these records, not stored
  # answer options).
  let!(:age_type) { create(:category_type, name: "AgeRange", published: true) }
  let!(:age_children) { create(:category, category_type: age_type, name: "Children (0-12)", published: true) }
  let!(:age_teens) { create(:category, category_type: age_type, name: "Teens (13-17)", published: true) }
  let!(:age_adults) { create(:category, category_type: age_type, name: "Adults (18+)", published: true) }
  let!(:sector_education) { create(:sector, :published, name: "Education") }
  let!(:sector_mental_health) { create(:sector, :published, name: "Mental Health") }
  let!(:sector_dv) { create(:sector, :published, name: "Domestic Violence") }

  let(:user) { create(:user) }
  # A returning registrant whose name, email, primary address, and phone are on
  # file — so the logged_out_only identity / mailing / phone fields are hidden when
  # signed in, leaving the always-ask + answers-on-file questions to fill.
  let(:logged_in_person) do
    person = create(:person, user: user, first_name: "Dana", last_name: "Lee",
                    email: "dana.lee@example.com", email_type: "personal")
    person.addresses.create!(street_address: "1 A St", city: "Oakland", state: "CA",
                             zip_code: "94601", locality: "Unknown", address_type: "personal", primary: true)
    person.contact_methods.create!(kind: :phone, value: "555-000-1111", contact_type: "personal", primary: true)
    person
  end

  before do
    driven_by(:rack_test)
    EventForm.create!(event: event, form: registration_form, role: "registration")
    EventForm.create!(event: event, form: continuing_education_form, role: "continuing_education")
    EventForm.create!(event: event, form: scholarship_form, role: "scholarship")
    EventForm.create!(event: event, form: bulk_payment_form, role: "bulk_payment")
  end

  describe "registration form" do
    it "incognito: persists every answer and its person / registration side effects" do
      visit new_event_public_registration_path(event)

      fill_full_registration

      choose_pr_radio ce_field("ce_credit_interest"), "Yes"
      choose_pr_radio reg_field("payment_method"), "Check"
      choose_pr_radio reg_field("someone_else_will_pay"), "Yes"
      check_pr_box reg_field("additional_forms"), "W-9"

      click_button "Register"
      expect(page).to have_content("successfully registered")

      person = Person.find_by!(email: "robin.avery@example.com")
      expect(person).to have_attributes(first_name: "Robin", last_name: "Avery", pronouns: "they/them",
                                        email_2: "robin.alt@example.com")

      registration = event.event_registrations.find_by!(registrant: person)
      expect(registration).to have_attributes(scholarship_requested: false,
                                              w9_requested: true, invoice_requested: false,
                                              someone_else_will_pay: true)
      expect(registration.continuing_education_registrations.count).to eq(1)

      answers = answers_by_identifier(registration_form.form_submissions.find_by!(person: person))
      expect(answers).to include(
        "first_name" => "Robin",
        "last_name" => "Avery",
        "primary_email" => "robin.avery@example.com",
        "primary_email_type" => "Personal",
        "pronouns" => "they/them",
        "secondary_email" => "robin.alt@example.com",
        "secondary_email_type" => "Work",
        "mailing_street" => "123 Main St",
        "mailing_address_type" => "Personal",
        "mailing_city" => "Los Angeles",
        "mailing_state" => "CA",
        "mailing_zip" => "90001",
        "mailing_country" => "United States",
        "phone" => "555-123-4567",
        "phone_type" => "Work",
        "agency_name" => "Hope Center",
        "agency_position" => "Art Therapist",
        "agency_website" => "https://hope.example.org",
        "agency_type" => "501c3/nonprofit",
        "agency_country" => "United States",
        "primary_sector_single" => sector_education.id.to_s,
        "additional_sectors" => sector_mental_health.id.to_s,
        "primary_age_group" => age_adults.id.to_s,
        "additional_age_group" => age_teens.id.to_s,
        "racial_ethnic_identity" => "Multi-racial",
        "referral_source" => "Online Search",
        "training_motivation" => "Address staff burnout through art",
        "payment_method" => "Check",
        "someone_else_will_pay" => "Yes",
        "additional_forms" => "W-9",
        "communication_consent" => "Yes"
      )
      expect(answers).not_to have_key("ce_credit_interest")

      ce_submission = continuing_education_form.form_submissions.find_by!(person: person)
      ce_answers = answers_by_identifier(ce_submission)
      expect(ce_answers).to include("ce_credit_interest" => "Yes")
      # The service never stores the confirm_email answer (it only checks it matches).
      expect(answers).not_to have_key("confirm_email")

      address = person.addresses.find_by(primary: true)
      expect(address).to have_attributes(city: "Los Angeles", state: "CA", zip_code: "90001")
      expect(person.contact_methods.find_by(kind: :phone).value).to eq("555-123-4567")
      expect(person.sectorable_items.map(&:sector)).to include(sector_education, sector_mental_health)
      expect(person.primary_age_groups).to include(age_adults)
      expect(person.additional_age_groups).to include(age_teens)
    end

    it "logged in: reuses the signed-in person, hides known fields, saves the rest" do
      logged_in_person
      sign_in user

      visit new_event_public_registration_path(event)

      # Known identity / mailing / phone questions are hidden for a returning person.
      expect(page).not_to have_selector("##{pr_dom_id(reg_field('first_name'))}")
      expect(page).not_to have_selector("##{pr_dom_id(reg_field('mailing_city'))}")

      select_pr reg_field("primary_sector_single"), "Education"
      check_pr_box reg_field("additional_sectors"), sector_dv.id.to_s
      select_pr reg_field("primary_age_group"), "Teens (13-17)"
      choose_pr_radio reg_field("racial_ethnic_identity"), "Asian"
      choose_pr_radio reg_field("referral_source"), "Social Media"
      choose_pr_radio reg_field("payment_method"), "Check"
      choose_pr_radio reg_field("someone_else_will_pay"), "No"
      choose_pr_radio ce_field("ce_credit_interest"), "No"
      check_pr_box reg_field("communication_consent"), "Yes"

      expect { click_button "Register" }.not_to change(Person, :count)
      expect(page).to have_content("successfully registered")

      registration = event.event_registrations.find_by!(registrant: logged_in_person)
      expect(registration).to be_present

      answers = answers_by_identifier(registration_form.form_submissions.find_by!(person: logged_in_person))
      expect(answers).to include(
        "primary_sector_single" => sector_education.id.to_s,
        "additional_sectors" => sector_dv.id.to_s,
        "primary_age_group" => age_teens.id.to_s,
        "racial_ethnic_identity" => "Asian",
        "referral_source" => "Social Media",
        "payment_method" => "Check",
        "someone_else_will_pay" => "No",
        "communication_consent" => "Yes"
      )
      logged_in_person.reload
      expect(logged_in_person.primary_age_groups).to include(age_teens)
      expect(logged_in_person.sectorable_items.map(&:sector)).to include(sector_education, sector_dv)
    end
  end

  describe "scholarship application (scholarship_requested=true)" do
    it "incognito: saves the registration and a separate scholarship submission" do
      visit new_event_public_registration_path(event, scholarship_requested: true)

      fill_full_registration
      choose_pr_radio reg_field("payment_method"), "Check"
      choose_pr_radio reg_field("someone_else_will_pay"), "No"
      choose_pr_radio ce_field("ce_credit_interest"), "No"

      choose_pr_radio schol_field("scholarship_eligibility"), "Yes"
      fill_pr_text schol_field("scholarship_contribution"), with: "Our agency can pay $200."
      fill_pr_text schol_field("impact_description"), with: "Art gives the survivors I serve a safer way to process trauma."
      fill_pr_text schol_field("implementation_plan"), with: "I'll run a weekly drop-in workshop at our advocacy center."
      fill_pr_text schol_field("additional_comments"), with: "Thank you for considering my application."

      click_button "Register"
      expect(page).to have_content("successfully registered")

      person = Person.find_by!(email: "robin.avery@example.com")
      registration = event.event_registrations.find_by!(registrant: person)
      expect(registration.scholarship_requested).to be(true)

      scholarship_submission = scholarship_form.form_submissions.find_by!(person: person, role: "scholarship")
      expect(answers_by_identifier(scholarship_submission)).to include(
        "scholarship_eligibility" => "Yes",
        "scholarship_contribution" => "Our agency can pay $200.",
        "impact_description" => "Art gives the survivors I serve a safer way to process trauma.",
        "implementation_plan" => "I'll run a weekly drop-in workshop at our advocacy center.",
        "additional_comments" => "Thank you for considering my application."
      )
    end

    it "logged in: flags the registration and saves the scholarship answers for the signed-in person" do
      logged_in_person
      sign_in user

      visit new_event_public_registration_path(event, scholarship_requested: true)

      choose_pr_radio reg_field("payment_method"), "Check"
      choose_pr_radio reg_field("someone_else_will_pay"), "No"
      choose_pr_radio ce_field("ce_credit_interest"), "No"
      check_pr_box reg_field("communication_consent"), "Yes"

      choose_pr_radio schol_field("scholarship_eligibility"), "Yes"
      fill_pr_text schol_field("impact_description"), with: "The clients I serve open up through making art."
      fill_pr_text schol_field("implementation_plan"), with: "A six-week recovery group built around weekly art prompts."

      click_button "Register"
      expect(page).to have_content("successfully registered")

      registration = event.event_registrations.find_by!(registrant: logged_in_person)
      expect(registration.scholarship_requested).to be(true)

      scholarship_submission = scholarship_form.form_submissions.find_by!(person: logged_in_person, role: "scholarship")
      expect(answers_by_identifier(scholarship_submission)).to include(
        "scholarship_eligibility" => "Yes",
        "impact_description" => "The clients I serve open up through making art.",
        "implementation_plan" => "A six-week recovery group built around weekly art prompts."
      )
    end
  end

  describe "bulk payment form" do
    it "incognito: creates the payer and saves the bulk payment submission" do
      visit new_event_bulk_payment_path(event)

      fill_bp_text bp_field("payer_first_name"), with: "Pat"
      fill_bp_text bp_field("payer_last_name"), with: "Morgan"
      fill_bp_text bp_field("payer_email"), with: "pat.morgan@example.com"
      fill_bp_text bp_field("payer_phone"), with: "555-987-6543"
      fill_bp_text bp_field("payer_organization"), with: "Group Health"
      fill_bp_text bp_field("number_of_attendees"), with: "3"
      choose_bp_radio bp_field("payment_method"), "Check"

      click_button "Submit"
      expect(page).to have_content("payment information has been submitted")

      person = Person.find_by!(email: "pat.morgan@example.com")
      expect(person).to have_attributes(first_name: "Pat", last_name: "Morgan")

      submission = FormSubmission.bulk_payment.find_by!(person: person, event: event)
      expect(answers_by_identifier(submission)).to include(
        "payer_first_name" => "Pat",
        "payer_last_name" => "Morgan",
        "payer_email" => "pat.morgan@example.com",
        "payer_phone" => "555-987-6543",
        "payer_organization" => "Group Health",
        "number_of_attendees" => "3",
        "payment_method" => "Check"
      )
      expect(person.contact_methods.find_by(kind: :phone).value).to eq("555-987-6543")
    end

    it "logged in: hides the payer fields and bills the signed-in person" do
      logged_in_person
      sign_in user

      visit new_event_bulk_payment_path(event)

      expect(page).not_to have_selector("#bulk_payment_form_fields_#{bp_field('payer_first_name').id}")

      fill_bp_text bp_field("number_of_attendees"), with: "2"
      choose_bp_radio bp_field("payment_method"), "Check"

      expect { click_button "Submit" }.not_to change(Person, :count)
      expect(page).to have_content("payment information has been submitted")

      submission = FormSubmission.bulk_payment.find_by!(person: logged_in_person, event: event)
      expect(answers_by_identifier(submission)).to include(
        "number_of_attendees" => "2",
        "payment_method" => "Check"
      )
    end
  end

  # ---- Form construction (mirrors the dev seeds) ----

  # Builds the registration form the way db/seeds/dev/events_management.rb does:
  # the full set of sections, minus the generic "interested in more?" question,
  # plus the "Additional forms" question whose answers drive the resulting
  # registration's flags.
  def build_registration_form
    form = FormBuilderService.new(
      name: "Training Registration Form",
      sections: %i[person_identifier person_contact_info professional_info person_background marketing payment consent],
      role: "registration"
    ).call
    form.form_fields.where(field_identifier: "interested_in_more").destroy_all

    position = form.form_fields.maximum(:position).to_i
    additional_forms = form.form_fields.create!(
      name: "Do you need either of the following?",
      answer_type: :multi_select_checkbox, status: :active, position: position += 1, required: false,
      field_identifier: EventRegistrationServices::PublicRegistration::ADDITIONAL_FORMS_IDENTIFIER,
      section: "additional_forms", visibility: :always_ask
    )
    [ EventRegistrationServices::PublicRegistration::ADDITIONAL_FORMS_W9,
      EventRegistrationServices::PublicRegistration::ADDITIONAL_FORMS_INVOICE,
      "No forms needed" ].each do |name|
      additional_forms.form_field_answer_options.create!(answer_option: AnswerOption.find_or_create_by!(name: name))
    end

    form
  end

  def build_continuing_education_form
    FormBuilderService.new(
      name: "Continuing Education Request",
      sections: %i[continuing_education],
      role: "continuing_education"
    ).call
  end

  # ---- Field lookup ----

  def reg_field(identifier)
    registration_form.form_fields.find_by!(field_identifier: identifier)
  end

  def ce_field(identifier)
    continuing_education_form.form_fields.find_by!(field_identifier: identifier)
  end

  def schol_field(identifier)
    scholarship_form.form_fields.find_by!(field_identifier: identifier)
  end

  def bp_field(identifier)
    bulk_payment_form.form_fields.find_by!(field_identifier: identifier)
  end

  def pr_dom_id(field)
    "public_registration_form_fields_#{field.id}"
  end

  # ---- Form interaction (public_registration namespace; shared by the
  # registration and appended scholarship fields) ----

  def fill_pr_text(field, with:)
    fill_in pr_dom_id(field), with: with
  end

  def select_pr(field, text)
    select text, from: pr_dom_id(field)
  end

  # Radios/checkboxes carry no id, so target them by their submitted name + value.
  def choose_pr_radio(field, value)
    find("input[type='radio'][name='public_registration[form_fields][#{field.id}]'][value='#{value}']").set(true)
  end

  def check_pr_box(field, value)
    find("input[type='checkbox'][name='public_registration[form_fields][#{field.id}][]'][value='#{value}']").set(true)
  end

  # ---- Form interaction (bulk_payment namespace) ----

  def fill_bp_text(field, with:)
    fill_in "bulk_payment_form_fields_#{field.id}", with: with
  end

  def choose_bp_radio(field, value)
    find("input[type='radio'][name='bulk_payment[form_fields][#{field.id}]'][value='#{value}']").set(true)
  end

  # Fills every visible registration question for a logged-out registrant.
  def fill_full_registration
    fill_pr_text reg_field("first_name"), with: "Robin"
    fill_pr_text reg_field("last_name"), with: "Avery"
    fill_pr_text reg_field("primary_email"), with: "robin.avery@example.com"
    fill_pr_text reg_field("confirm_email"), with: "robin.avery@example.com"
    choose_pr_radio reg_field("primary_email_type"), "Personal"
    fill_pr_text reg_field("pronouns"), with: "they/them"
    fill_pr_text reg_field("secondary_email"), with: "robin.alt@example.com"
    choose_pr_radio reg_field("secondary_email_type"), "Work"

    fill_pr_text reg_field("mailing_street"), with: "123 Main St"
    choose_pr_radio reg_field("mailing_address_type"), "Personal"
    fill_pr_text reg_field("mailing_city"), with: "Los Angeles"
    select_pr reg_field("mailing_state"), "California (CA)"
    fill_pr_text reg_field("mailing_zip"), with: "90001"
    fill_pr_text reg_field("mailing_country"), with: "United States"
    fill_pr_text reg_field("phone"), with: "555-123-4567"
    choose_pr_radio reg_field("phone_type"), "Work"

    fill_pr_text reg_field("agency_name"), with: "Hope Center"
    fill_pr_text reg_field("agency_position"), with: "Art Therapist"
    fill_pr_text reg_field("agency_website"), with: "https://hope.example.org"
    choose_pr_radio reg_field("agency_type"), "501c3/nonprofit"
    fill_pr_text reg_field("agency_street"), with: "9 Center Ave"
    fill_pr_text reg_field("agency_city"), with: "Pasadena"
    select_pr reg_field("agency_state"), "California (CA)"
    fill_pr_text reg_field("agency_zip"), with: "91101"
    fill_pr_text reg_field("agency_country"), with: "United States"

    select_pr reg_field("primary_sector_single"), "Education"
    check_pr_box reg_field("additional_sectors"), sector_mental_health.id.to_s
    select_pr reg_field("primary_age_group"), "Adults (18+)"
    check_pr_box reg_field("additional_age_group"), age_teens.id.to_s

    choose_pr_radio reg_field("racial_ethnic_identity"), "Multi-racial"
    choose_pr_radio reg_field("referral_source"), "Online Search"
    check_pr_box reg_field("training_motivation"), "Address staff burnout through art"

    check_pr_box reg_field("communication_consent"), "Yes"
  end

  # ---- Assertions ----

  def answers_by_identifier(submission)
    submission.form_answers.includes(:form_field).each_with_object({}) do |answer, hash|
      identifier = answer.form_field.field_identifier
      hash[identifier] = answer.submitted_answer if identifier.present?
    end
  end
end
