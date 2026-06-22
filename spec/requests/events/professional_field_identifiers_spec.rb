require "rails_helper"

# The four professional registration questions (primary/additional sector and
# primary/additional age group) resolve their options dynamically from Sector /
# AgeRange records and must keep working across every legacy field_identifier a
# form might still carry. For each identifier scheme this exercises, end to end:
#
#   * option rendering — the "primary" fields are dropdowns of the published
#     options minus the catch-all ("Other" sector / "Mixed-age groups"); the
#     additional sector field keeps "Other", but the additional age field also
#     drops "Mixed-age groups" (age groups never offer a catch-all);
#   * submission storage into form_answers (including a folded "Other: <text>");
#   * the primary/additional split recorded as person sector/age tags; and
#   * that the stored selections are readable on the person show, person edit,
#     and form-submission show pages.
RSpec.describe "Events::PublicRegistrations professional fields", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, cost_cents: 0) }

  # An AgeRange type (profile-specific so the person edit form lists it) with the
  # concrete ranges, the catch-all "Mixed-age groups", and an unpublished range
  # that must never be offered.
  let!(:age_type) { create(:category_type, name: "AgeRange", published: true, profile_specific: true) }
  let!(:age_children) { create(:category, category_type: age_type, name: "Children (0-12)", published: true) }
  let!(:age_teens)    { create(:category, category_type: age_type, name: "Teens (13-17)", published: true) }
  let!(:age_adults)   { create(:category, category_type: age_type, name: "Adults (18+)", published: true) }
  let!(:age_mixed)    { create(:category, category_type: age_type, name: Category::MIXED_AGE_RANGE_NAME, published: true) }
  let!(:age_hidden)   { create(:category, category_type: age_type, name: "Unpublished range", published: false) }

  let!(:sector_education) { create(:sector, :published, name: "Education") }
  let!(:sector_mh)        { create(:sector, :published, name: "Mental Health") }
  let!(:sector_other)     { create(:sector, :published, name: Sector::OTHER_SECTOR_NAME) }
  let!(:sector_hidden)    { create(:sector, name: "Hidden sector") }

  # Each scheme maps the two sector fields onto a canonical or legacy identifier;
  # the age-group fields have never been renamed, so they stay constant.
  {
    "canonical identifiers"         => { primary_sector: "primary_sector_single",       additional_sector: "additional_sectors" },
    "legacy additional-sector name" => { primary_sector: "primary_sector_single",       additional_sector: "primary_sector" },
    "legacy service-area names"     => { primary_sector: "primary_service_area_single", additional_sector: "primary_service_area" }
  }.each do |scheme_name, ids|
    context "with #{scheme_name}" do
      let(:form) { build_professional_form(ids) }
      let(:primary_sector_field)    { form.form_fields.find_by!(field_identifier: ids[:primary_sector]) }
      let(:additional_sector_field) { form.form_fields.find_by!(field_identifier: ids[:additional_sector]) }
      let(:primary_age_field)       { form.form_fields.find_by!(field_identifier: "primary_age_group") }
      let(:additional_age_field)    { form.form_fields.find_by!(field_identifier: "additional_age_group") }

      before { EventForm.create!(event: event, form: form, role: "registration") }

      describe "GET new (option rendering)" do
        before { get new_event_public_registration_path(event) }

        it "renders the primary fields as dropdowns of published options minus the catch-all" do
          expect(select_option_values(primary_sector_field)).to include(sector_education.id.to_s, sector_mh.id.to_s)
          expect(select_option_values(primary_sector_field)).not_to include(sector_other.id.to_s, sector_hidden.id.to_s)

          expect(select_option_values(primary_age_field)).to include(age_children.id.to_s, age_teens.id.to_s, age_adults.id.to_s)
          expect(select_option_values(primary_age_field)).not_to include(age_mixed.id.to_s, age_hidden.id.to_s)
        end

        it "renders the additional fields as checkboxes — sectors keep Other, age groups drop Mixed-age groups" do
          sector_values = checkbox_values(additional_sector_field)
          expect(sector_values).to include(sector_education.id.to_s, sector_mh.id.to_s)
          # The "Other" sector renders a free-text box, so its checkbox submits the
          # literal "Other" rather than the sector id.
          expect(sector_values).to include(Sector::OTHER_SECTOR_NAME)
          expect(sector_values).not_to include(sector_hidden.id.to_s)

          age_values = checkbox_values(additional_age_field)
          expect(age_values).to include(age_children.id.to_s, age_teens.id.to_s, age_adults.id.to_s)
          # Additional age groups drop the catch-all "Mixed-age groups" (and never
          # offer an "Other"), unlike additional sectors.
          expect(age_values).not_to include(age_mixed.id.to_s, age_hidden.id.to_s)
        end
      end

      describe "POST create (storage, tags, and display)" do
        let(:registrant) { Person.find_by!(email: "robin.avery@example.com") }
        let(:submission) { form.form_submissions.find_by!(person: registrant) }

        before do
          post event_public_registration_path(event), params: { public_registration: { form_fields: {
            fid("first_name") => "Robin",
            fid("last_name") => "Avery",
            fid("primary_email") => "robin.avery@example.com",
            fid("confirm_email") => "robin.avery@example.com",
            primary_sector_field.id.to_s => sector_education.id.to_s,
            additional_sector_field.id.to_s => [ sector_mh.id.to_s, "Other: Equine therapy" ],
            primary_age_field.id.to_s => age_adults.id.to_s,
            additional_age_field.id.to_s => [ age_teens.id.to_s, age_children.id.to_s ]
          } } }
        end

        it "succeeds rather than rejecting the dynamic Other selection" do
          expect(response).to have_http_status(:found)
          expect(EventRegistration.where(registrant: registrant)).to exist
        end

        it "stores each professional answer in form_answers" do
          expect(answers_by_identifier(submission)).to include(
            ids[:primary_sector] => sector_education.id.to_s,
            ids[:additional_sector] => "#{sector_mh.id}, Other: Equine therapy",
            "primary_age_group" => age_adults.id.to_s,
            "additional_age_group" => "#{age_teens.id}, #{age_children.id}"
          )
        end

        it "tags the person with the primary/additional split and captures the Other free text" do
          expect(primary_sector_of(registrant)).to eq(sector_education)
          expect(additional_sectors_of(registrant)).to contain_exactly(sector_mh)
          expect(registrant.other_sector_responses).to include("Equine therapy")
          expect(registrant.primary_age_groups).to contain_exactly(age_adults)
          expect(registrant.additional_age_groups).to contain_exactly(age_teens, age_children)
        end

        it "shows the resolved names on the person show page" do
          sign_in admin
          get person_path(registrant)

          expect(response.body).to include("Education", "Mental Health", "Adults (18+)", "Teens (13-17)", "Children (0-12)")
          expect(response.body).to include("Equine therapy")
        end

        it "shows the tagged sectors and the checked age groups on the person edit page" do
          sign_in admin
          get edit_person_path(registrant)
          page = dom

          # Sector chips render only for tagged sectors, so their presence proves the tag.
          expect(page.text).to include("Education", "Mental Health", "Equine therapy")
          # Age categories all render as checkboxes; the tagged ones are checked, with
          # the primary toggle set only on the primary age group.
          expect(membership_checked?(page, age_adults)).to be(true)
          expect(membership_checked?(page, age_teens)).to be(true)
          expect(membership_checked?(page, age_children)).to be(true)
          expect(primary_age_checked?(page, age_adults)).to be(true)
          expect(primary_age_checked?(page, age_teens)).to be(false)
        end

        it "resolves the stored ids to names on the form submission show page" do
          sign_in admin
          get form_submission_path(submission)

          expect(response.body).to include("Education")
          expect(response.body).to include("Mental Health, Other: Equine therapy")
          expect(response.body).to include("Adults (18+)")
          expect(response.body).to include("Teens (13-17), Children (0-12)")
        end
      end
    end
  end

  # ---- Form construction ----

  # Builds a registration form with just the identity + professional sections,
  # then renames the two sector fields onto the scheme's identifiers (the age
  # fields keep their canonical names — they were never renamed).
  def build_professional_form(ids)
    form = FormBuilderService.new(
      name: "Reg #{ids[:primary_sector]} / #{ids[:additional_sector]}",
      sections: %i[person_identifier professional_info],
      role: "registration"
    ).call
    rename_field(form, "primary_sector_single", ids[:primary_sector])
    rename_field(form, "additional_sectors", ids[:additional_sector])
    form
  end

  def rename_field(form, from, to)
    return if from == to
    form.form_fields.find_by!(field_identifier: from).update!(field_identifier: to)
  end

  def fid(identifier)
    form.form_fields.find_by!(field_identifier: identifier).id.to_s
  end

  # ---- DOM helpers ----

  def dom(body = response.body)
    Nokogiri::HTML(body)
  end

  def select_option_values(field)
    dom.at_css("#public_registration_form_fields_#{field.id}")
       .css("option").map { |option| option["value"] }.reject(&:blank?)
  end

  def checkbox_values(field)
    dom.css("input[type=checkbox][name='public_registration[form_fields][#{field.id}][]']").map { |node| node["value"] }
  end

  def membership_checked?(page, category)
    box = page.at_css("input[name='person[category_ids][]'][value='#{category.id}']")
    box&.key?("checked") || false
  end

  def primary_age_checked?(page, category)
    box = page.at_css("input[name='person[primary_age_category_ids][]'][value='#{category.id}']")
    box&.key?("checked") || false
  end

  # ---- Assertions ----

  def answers_by_identifier(submission)
    submission.form_answers.includes(:form_field).each_with_object({}) do |answer, hash|
      identifier = answer.form_field.field_identifier
      hash[identifier] = answer.submitted_answer if identifier.present?
    end
  end

  def primary_sector_of(person)
    person.sectorable_items.find(&:is_primary?)&.sector
  end

  def additional_sectors_of(person)
    person.sectorable_items.reject(&:is_primary?).map(&:sector)
  end
end
