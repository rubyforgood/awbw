# Dev-only: give one known-named person (Maria Johnson) a registration that
# arrived AFTER she was already in the database and edited several details that
# were already on record — so the admin "what this form submission changed" page
# has a rich, realistic example. The edits are stored as stamped Ahoy lifecycle
# events (the same shape the live registration flow produces), keyed to her
# registration's form submission.

event = Event.joins(:event_forms).where(event_forms: { role: "registration" }).first
registration_form = event&.registration_form
maria = Person.find_by("LOWER(first_name) = ? AND LOWER(last_name) = ?", "maria", "johnson")

if maria.nil? || registration_form.nil?
  puts "  Skipping form-submission-changes seed (missing Maria or a registration form/event)."
else
  org = maria.organizations.first || Organization.first

  # Move Maria and her org into their post-registration ("after") state; the
  # events below carry the previous values so the page can show what changed.
  maria.update!(racial_ethnic_identity: "Latina")
  address = maria.addresses.order(:id).first ||
    maria.addresses.create!(street_address: "250 New Ave", city: "Los Angeles", state: "CA", zip_code: "90012", locality: "LA City", address_type: "mailing", primary: true)
  address.update!(street_address: "250 New Ave", zip_code: "90012")
  phone = maria.contact_methods.where(kind: :phone).order(:id).first ||
    maria.contact_methods.create!(kind: :phone, value: "(310) 555-0199", contact_type: "personal", primary: true)
  phone.update!(value: "(310) 555-0199")
  org&.update!(website_url: "newsite.org", agency_type: "Hospital")

  submission = FormSubmission.find_or_create_by!(person: maria, form: registration_form, event: event, role: "registration") do |record|
    record.created_at = 2.days.ago
  end

  # Surface it on the linked-organizations and registrant-submission pages too.
  begin
    if org
      registration = EventRegistration.find_or_create_by!(registrant: maria, event: event)
      registration.event_registration_organizations.find_or_create_by!(organization: org).record_form_submission(submission)
    end
  rescue ActiveRecord::RecordInvalid => e
    puts "  (Couldn't attach a registration for the linking-page demo: #{e.message})"
  end

  if Ahoy::Event.where("properties->>'$.form_submission_id' = ?", submission.id.to_s).exists?
    puts "  Form-submission-changes seed already present for #{maria.full_name}."
  else
    visit = Ahoy::Visit.create!(visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid, started_at: 2.days.ago)

    edits = [
      { name: "update.person", type: "Person", id: maria.id, title: maria.full_name,
        changes: { "racial_ethnic_identity" => { "before" => "Prefer not to say", "after" => "Latina" } } },
      { name: "update.address", type: "Address", id: address.id, title: maria.full_name,
        attributes: { "addressable_type" => "Person", "addressable_id" => maria.id },
        changes: { "street_address" => { "before" => "100 Old St", "after" => "250 New Ave" },
                   "zip_code" => { "before" => "90001", "after" => "90012" } } },
      { name: "update.contact_method", type: "ContactMethod", id: phone.id, title: maria.full_name,
        attributes: { "contactable_type" => "Person", "contactable_id" => maria.id },
        changes: { "value" => { "before" => "(310) 555-0001", "after" => "(310) 555-0199" } } }
    ]
    if org
      edits << { name: "update.organization", type: "Organization", id: org.id, title: org.name,
                 changes: { "website_url" => { "before" => "oldsite.org", "after" => "newsite.org" },
                            "agency_type" => { "before" => "Nonprofit", "after" => "Hospital" } } }
    end

    edits.each do |edit|
      properties = { "resource_type" => edit[:type], "resource_id" => edit[:id], "resource_title" => edit[:title],
                     "form_submission_id" => submission.id, "changes" => edit[:changes] }
      properties["attributes"] = edit[:attributes] if edit[:attributes]
      Ahoy::Event.create!(visit: visit, name: edit[:name], resource_type: edit[:type], resource_id: edit[:id],
                          properties: properties, time: 2.days.ago)
    end

    puts "  Seeded a post-registration edit trail for #{maria.full_name} (#{edits.sum { |edit| edit[:changes].size }} changed values)."
  end
end
