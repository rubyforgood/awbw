# Builds the unsaved, data-free registration the sample ticket (and its
# admin-only callout page previews) render from. Nothing is ever persisted, so
# the preview can never read from or write to a real registrant, nor leak into
# counts, revenue, rosters, or reminders. Shared by EventsController#sample_ticket
# and Events::CalloutsController's sample mode so both preview the same person.
class SampleTicketRegistration
  # `all_options` mirrors the ticket's "Show all options" toggle: it turns on the
  # scholarship/CE/W-9 flags so those callout cards (and their preview pages)
  # render as they would for a registrant using every option.
  def initialize(event, all_options: false)
    @event = event
    @all_options = all_options
  end

  def registration
    registrant = Person.new(first_name: "Sample", last_name: "Person")
    registration = @event.event_registrations.new(
      registrant: registrant,
      slug: "sample",
      status: "registered",
      intends_to_pay: true,
      w9_requested: @all_options,
      invoice_requested: @all_options,
      scholarship_requested: @all_options,
      shoutout: @all_options,
      created_at: Time.current
    )
    build_ce_registration(registration) if @all_options
    registration
  end

  private

  def build_ce_registration(registration)
    license = ProfessionalLicense.new(person: registration.registrant, number: "SAMPLE-12345")
    registration.continuing_education_registrations.build(
      professional_license: license,
      hours: @event.ce_hours_offered || 6,
      cost_cents: @event.ce_hours_cost_cents || 15_000
    )
  end
end
