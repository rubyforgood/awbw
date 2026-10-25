require "rails_helper"

RSpec.describe "Outside USA? state boxes", type: :request do
  def page_html
    Nokogiri::HTML(response.body)
  end

  describe "a license on the person form" do
    let(:person) { create(:person) }

    before { sign_in create(:user, :admin) }

    it "opens the box on a saved state the US list can't show, leaving the dropdown blank" do
      create(:professional_license, person: person, issuing_state: "Ontario")

      get edit_person_path(person)

      box = page_html.at_css("input[name$='[issuing_state_outside_usa]']")
      expect(box["value"]).to eq("Ontario")
      expect(box.ancestors("details").first["open"]).not_to be_nil
      expect(page_html.at_css("select[name$='[issuing_state]'] option[selected]")).to be_nil
    end

    it "keeps the box closed on a US state" do
      create(:professional_license, person: person, issuing_state: "CA")

      get edit_person_path(person)

      expect(page_html.at_css("input[name$='[issuing_state_outside_usa]']").ancestors("details").first["open"]).to be_nil
      expect(page_html.at_css("select[name$='[issuing_state]'] option[selected]")["value"]).to eq("CA")
    end

    it "opens the box on a license from another country" do
      create(:professional_license, person: person, issuing_state: nil, issuing_country: "Canada")

      get edit_person_path(person)

      country = page_html.at_css("select[name$='[issuing_country]']")
      expect(country.at_css("option[selected]")["value"]).to eq("Canada")
      expect(country.ancestors("details").first["open"]).not_to be_nil
    end

    it "saves a typed state and country over the blank dropdown" do
      license = create(:professional_license, person: person, issuing_state: "CA")

      patch person_path(person), params: { person: { professional_licenses_attributes: { "0" => {
        id: license.id, issuing_state: "", issuing_state_outside_usa: "Ontario", issuing_country: "Canada"
      } } } }

      expect(license.reload).to have_attributes(issuing_state: "Ontario", issuing_country: "Canada")
    end

    it "saves a typed state and country over a US state picked first" do
      license = create(:professional_license, person: person, issuing_state: "CA")

      patch person_path(person), params: { person: { professional_licenses_attributes: { "0" => {
        id: license.id, issuing_state: "CA", issuing_state_outside_usa: "Ontario", issuing_country: "Canada"
      } } } }

      expect(license.reload).to have_attributes(issuing_state: "Ontario", issuing_country: "Canada")
    end

    it "leaves the country blank for a typed state with no country picked" do
      license = create(:professional_license, person: person, issuing_state: "CA")

      patch person_path(person), params: { person: { professional_licenses_attributes: { "0" => {
        id: license.id, issuing_state: "CA", issuing_state_outside_usa: "Ontario", issuing_country: ""
      } } } }

      expect(license.reload).to have_attributes(issuing_state: "Ontario", issuing_country: be_blank)
    end

    it "records the US for a US state with no country picked" do
      license = create(:professional_license, person: person, issuing_state: "Ontario", issuing_country: "Canada")

      patch person_path(person), params: { person: { professional_licenses_attributes: { "0" => {
        id: license.id, issuing_state: "NY", issuing_state_outside_usa: "", issuing_country: ""
      } } } }

      expect(license.reload).to have_attributes(issuing_state: "NY", issuing_country: "United States")
    end

    it "adds a license that only has a typed state" do
      expect {
        patch person_path(person), params: { person: { professional_licenses_attributes: { "0" => {
          number: "", kind: "", issuing_state: "", issuing_state_outside_usa: "Ontario"
        } } } }
      }.to change { person.professional_licenses.count }.by(1)
    end
  end

  describe "the CE callout license box" do
    let(:event) { create(:event) }
    let(:registration) { create(:event_registration, event: event) }
    let!(:license) { create(:professional_license, person: registration.registrant, number: nil, issuing_state: "Ontario") }

    before { create(:continuing_education_registration, event_registration: registration, professional_license: license) }

    it "opens the box on a saved state the US list can't show" do
      get registration_ce_path(registration.slug)

      expect(page_html.at_css("input#license_issuing_state_outside_usa")["value"]).to eq("Ontario")
    end

    it "saves a typed state and country" do
      post registration_ce_license_path(registration.slug), params: { license_number: "LIC-1", license_kind: "LCSW",
        license_issuing_state: "", license_issuing_state_outside_usa: "Quebec", license_issuing_country: "Canada" }

      expect(license.reload).to have_attributes(issuing_state: "Quebec", issuing_country: "Canada")
    end

    it "saves a typed state over a US state picked first" do
      post registration_ce_license_path(registration.slug), params: { license_number: "LIC-1", license_kind: "LCSW",
        license_issuing_state: "CA", license_issuing_state_outside_usa: "Quebec", license_issuing_country: "" }

      expect(license.reload).to have_attributes(issuing_state: "Quebec", issuing_country: be_blank)
    end

    it "records the US for a US state with no country picked" do
      post registration_ce_license_path(registration.slug), params: { license_number: "LIC-1", license_kind: "LCSW",
        license_issuing_state: "CA", license_issuing_state_outside_usa: "", license_issuing_country: "" }

      expect(license.reload).to have_attributes(issuing_state: "CA", issuing_country: "United States")
    end
  end

  describe "the admin CE registration form" do
    let(:registration) { create(:event_registration, event: create(:event, ce_hours_offered: 6)) }
    let(:license) { create(:professional_license, person: registration.registrant, kind: "LCSW", number: "1") }
    let(:ce_registration) { create(:continuing_education_registration, event_registration: registration, professional_license: license) }

    before { sign_in create(:user, :admin) }

    it "saves a typed state and country" do
      patch continuing_education_registration_path(ce_registration), params: { continuing_education_registration: {
        license_kind: "LCSW", license_number: "1", license_issuing_state: "CA", license_issuing_state_outside_usa: "Ontario",
        license_issuing_country: "Canada", hours: "6"
      } }

      expect(license.reload).to have_attributes(issuing_state: "Ontario", issuing_country: "Canada")
    end

    it "opens the box on the edit page for a license issued outside the USA" do
      license.update!(issuing_state: "Ontario", issuing_country: "Canada")

      get edit_continuing_education_registration_path(ce_registration)

      expect(page_html.at_css("#continuing_education_registration_license_issuing_state_outside_usa")["value"]).to eq("Ontario")
      expect(page_html.at_css("#continuing_education_registration_license_issuing_country option[selected]")["value"]).to eq("Canada")
    end
  end

  describe "a public form's state question" do
    let(:form) { create(:form, slug: "interest", published: true, anonymous: true) }
    let!(:state_field) { create(:form_field, form: form, name: "State", field_identifier: "mailing_state", required: true) }

    it "records a typed state as the answer" do
      post public_form_path(form.slug), params: { public_registration: {
        Honeypot::FIELD_NAME => "",
        form_fields: { state_field.id.to_s => "" },
        form_fields_outside_usa: { state_field.id.to_s => "Ontario" }
      } }

      expect(FormAnswer.find_by(form_field: state_field).submitted_answer).to eq("Ontario")
    end

    it "records a typed state over a US state picked first" do
      post public_form_path(form.slug), params: { public_registration: {
        Honeypot::FIELD_NAME => "",
        form_fields: { state_field.id.to_s => "CA" },
        form_fields_outside_usa: { state_field.id.to_s => "Ontario" }
      } }

      expect(FormAnswer.find_by(form_field: state_field).submitted_answer).to eq("Ontario")
    end

    context "with a matching country question" do
      let!(:country_field) { create(:form_field, form: form, name: "Country", field_identifier: "mailing_country") }

      it "asks the country inside the state's Outside USA? box only" do
        get public_form_path(form.slug)

        countries = page_html.css("select[name='public_registration[form_fields][#{country_field.id}]']")
        expect(countries.size).to eq(1)
        expect(countries.first.ancestors("details")).to be_present
      end

      it "records the country picked in the box" do
        post public_form_path(form.slug), params: { public_registration: {
          Honeypot::FIELD_NAME => "",
          form_fields: { state_field.id.to_s => "", country_field.id.to_s => "Canada" },
          form_fields_outside_usa: { state_field.id.to_s => "Ontario" }
        } }

        expect(FormAnswer.find_by(form_field: country_field).submitted_answer).to eq("Canada")
      end

      it "leaves an optional country blank for a typed state over a US state picked first" do
        country_field.update!(required: false)

        post public_form_path(form.slug), params: { public_registration: {
          Honeypot::FIELD_NAME => "",
          form_fields: { state_field.id.to_s => "CA", country_field.id.to_s => "" },
          form_fields_outside_usa: { state_field.id.to_s => "Ontario" }
        } }

        expect(FormAnswer.find_by(form_field: state_field).submitted_answer).to eq("Ontario")
        expect(FormAnswer.find_by(form_field: country_field)&.submitted_answer).to be_blank
      end

      it "records the US for a US state with no country picked" do
        post public_form_path(form.slug), params: { public_registration: {
          Honeypot::FIELD_NAME => "",
          form_fields: { state_field.id.to_s => "CA", country_field.id.to_s => "" },
          form_fields_outside_usa: { state_field.id.to_s => "" }
        } }

        expect(FormAnswer.find_by(form_field: country_field).submitted_answer).to eq("United States")
      end

      it "asks the country on its own when the state question is hidden for a logged-in respondent" do
        [ state_field, country_field ].each { |field| field.update!(visibility: :logged_out_only) }
        person = create(:person)
        create(:address, addressable: person, state: "CA", country: "United States")
        sign_in create(:user, person: person)

        get public_form_path(form.slug)

        expect(page_html.at_css("select[name='public_registration[form_fields][#{state_field.id}]']")).to be_nil
        country = page_html.at_css("select[name='public_registration[form_fields][#{country_field.id}]']")
        expect(country).to be_present
        expect(country.ancestors("details")).to be_empty
      end
    end

    it "keeps a typed state in its box when the form comes back with errors" do
      create(:form_field, form: form, name: "Pet", field_identifier: "pet_name", required: true)

      post public_form_path(form.slug), params: { public_registration: {
        Honeypot::FIELD_NAME => "",
        form_fields: { state_field.id.to_s => "" },
        form_fields_outside_usa: { state_field.id.to_s => "Ontario" }
      } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(page_html.at_css("input[name='public_registration[form_fields_outside_usa][#{state_field.id}]']")["value"]).to eq("Ontario")
    end
  end

  describe "a submitted registration's answers" do
    let(:event) { create(:event) }
    let(:person) { create(:person) }
    let!(:registration) { create(:event_registration, event: event, registrant: person) }
    let(:form) { create(:form) }
    let!(:state_field) { create(:form_field, form: form, name: "State", field_identifier: "mailing_state") }
    let!(:country_field) { create(:form_field, form: form, name: "Country", field_identifier: "mailing_country") }

    it "shows the country answered in the box on the confirmation page" do
      EventForm.create!(event: event, form: form, role: "registration")
      submission = form.form_submissions.create!(person: person, event: event)
      submission.form_answers.create!(form_field: state_field, submitted_answer: "Ontario")
      submission.form_answers.create!(form_field: country_field, submitted_answer: "Canada")

      get event_public_registration_path(event, reg: registration.slug)

      row = page_html.css("dt").find { |label| label.text.strip == "Country" }&.parent
      expect(row["class"]).not_to include("hidden")
      expect(row.at_css("dd").text).to include("Canada")
    end
  end
end
