# Materializes the built-in ("magic") ticket callouts into editable rows for an
# event. Run on event create and, for events that predate this, lazily on edit —
# so existing events heal the first time they're saved, with no data backfill.
#
# Each definition carries the callout's default content plus how its initial
# visibility (`hidden`) is derived from the event's config, using the same rules
# the code-defined cards used (see Event#show_*_callout?). Seeding is idempotent:
# a magic_key already present on the event is left untouched, so a re-run never
# clobbers admin edits.
#
# Only the content-and-resource cards (Handouts, FAQ) are materialized today; the
# stateful cards (payment, CE, scholarship, …) still render through
# MagicTicketCallouts until their per-registration behavior is keyed off the row.
# MagicTicketCallouts skips any card an event has already materialized, so the two
# paths never double-render.
class DefaultTicketCallouts
  # Default FAQ content for the 2-day training, mirrored from the code-defined FAQ
  # page so a newly materialized card starts with the current copy. Admins edit it
  # per event afterward.
  FAQS = [
    { q: "Who is this training designed for?",
      a: [ "This training is designed for anyone interested in incorporating healing arts into the work they do with individuals, groups, or communities. Participants come from a wide range of backgrounds, including education, mental health, social services, healthcare, community organizing, advocacy, and nonprofit work." ] },
    { q: "Do I need to be an artist or have art experience to participate?",
      a: [ "No prior art experience or artistic background is required to participate in the training. The AWBW approach is centered on the creative process rather than artistic skill or technique." ] },
    { q: "Is the training trauma-informed?",
      a: [ "Yes. The AWBW model, philosophy, and facilitation approach are rooted in trauma-informed practices. The training includes dedicated content focused on trauma-informed facilitation and creating supportive, inclusive environments for participants." ] },
    { q: "Do I need to work for an organization to participate in the training or become a facilitator?",
      a: [ "No. You do not need to be affiliated with an organization or agency to participate in the training or become an AWBW Facilitator. While many facilitators implement the workshops within organizations, schools, or community programs, others use the workshops in private practice, community spaces, support groups, creative gatherings, or personal healing work. The workshops are designed to be flexible and adaptable across a variety of settings and populations." ] },
    { q: "Can I use the workshops with youth? Adults? Families?",
      a: [ "Yes. AWBW workshops are designed to be flexible and adaptable for individuals of all ages, including youth, adults, families, and intergenerational groups.",
           "Within the facilitator portal, workshops can be searched and filtered by focus area, population, theme, and other categories to help facilitators find workshops that best fit the communities they serve." ] },
    { q: "How many workshops are included in the curriculum library?",
      a: [ "The AWBW facilitator portal includes access to a library of more than 600 art workshops and facilitation resources." ] },
    { q: "Are workshops available in Spanish or other languages?",
      a: [ "Yes. A number of workshops have been translated into Spanish. Within the facilitator portal, facilitators can use the search filters to locate workshops that include Spanish translations.",
           "AWBW continues to work toward increasing language accessibility and expanding translated resources over time." ] },
    { q: "What materials do I need for the art workshops?",
      a: [ "There are no required art materials for participation. Workshops can be completed using any materials you already have available, such as paper, pencils, pens, crayons, markers, colored pencils, paint, collage materials, or other creative supplies. The focus of the AWBW approach is on the creative process rather than the materials themselves.",
           "Prior to the training, we will also send participants a list of optional art supplies that may be helpful to have on hand, as well as printable worksheets for each of the art workshops that will be facilitated during the training. While neither the supplies nor the worksheets are required, many participants find them helpful for engaging more fully in the workshop experience.",
           "We will walk through the art supplies suggested for each workshop so that, if trainees choose to use those materials in their own facilitation, they feel familiar and comfortable incorporating those materials into their own facilitation practice." ] },
    { q: "What ongoing support does AWBW provide after completing the on-demand training?",
      a: [ "Once you complete the On-Demand Training and receive your certification, you become part of a thriving community of over 1,500 Windows Facilitators across the country and abroad, all learning from and supporting one another.",
           "As a certified facilitator, you'll gain access to:" ],
      list: [ "The AWBW Facilitator Portal, which houses a curriculum of over 600 art workshops, downloadable resources, toolkits, handouts, the Facilitator Manual, and tools for tracking attendance and gathering feedback",
              "Ongoing professional development, including live art workshops, Q&As, and recorded presentations by subject matter experts",
              "Virtual Community of Practice events, where you can connect with fellow facilitators and experience new workshops",
              "AWBW staff support for workshop selection, facilitation questions, art supply tips, and more",
              "A bi-monthly newsletter with new workshops, stories, and resources" ] },
    { q: "Can multiple staff members from one organization participate?",
      a: [ "Yes. Multiple staff members from the same organization are welcome and encouraged to participate in the training.",
           "Many organizations choose to train teams of staff members in order to integrate trauma-informed healing arts practices more broadly across their programs, services, and communities." ] },
    { q: "Are there any fees, other than the training fee, associated with becoming a facilitator?",
      a: [ "AWBW has an annual membership fee of $100 per program to support the sustainability of the organization and continued facilitator resources and support.",
           "The membership fee covers all facilitators connected to the same program or organization for the calendar year, regardless of the number of facilitators participating. Only one membership fee payment is required per program annually." ] }
  ].freeze

  # magic_keys this service knows how to materialize.
  def self.seedable_keys
    new(nil).send(:definitions).map { |definition| definition[:magic_key] }
  end

  def self.seed(event)
    new(event).seed
  end

  # Reset a materialized callout's content and default visibility back to its
  # built-in template, keeping its position. Used by the "Restore default" action.
  def self.reset(callout)
    new(callout.event).reset(callout)
  end

  def initialize(event)
    @event = event
  end

  # Create any not-yet-present magic callouts for the event, appended in
  # definition order after whatever already exists. A definition's optional
  # `seed_if` gates whether it applies to this event (e.g. skip the
  # videoconference card until the event has a link). Returns the created rows.
  def seed
    existing_keys = @event.registration_ticket_callouts.magic.pluck(:magic_key).to_set
    definitions.reject { |definition| existing_keys.include?(definition[:magic_key]) }
               .select { |definition| definition[:seed_if].nil? || definition[:seed_if].call(@event) }
               .map { |definition| create(definition) }
  end

  def reset(callout)
    definition = definitions.find { |candidate| candidate[:magic_key] == callout.magic_key }
    return callout unless definition

    callout.update!(
      title: definition[:title],
      subtitle: definition[:subtitle],
      description: definition[:description],
      callout_type: definition[:callout_type],
      icon_class: definition[:icon_class],
      color_class: definition[:color_class],
      hidden: definition[:hidden].call(@event),
      display_from: definition[:display_from]&.call(@event)
    )
    callout.resources = definition[:resources]&.call || []
    callout
  end

  private

  # Ordered built-in callout definitions. `hidden` / `display_from` are procs so
  # each event derives its own defaults; `resources` resolves the linked records;
  # `seed_if` gates whether the card applies. Content cards (Handouts, FAQ) render
  # their own copy; "behavioral" cards (Certificate, Videoconference) render live
  # per-registration status through MagicTicketCallouts#card_for — the row only
  # governs visibility, drip date, and order.
  def definitions
    [
      {
        magic_key: "payment",
        title: "Payment",
        subtitle: "Your balance and payment history",
        callout_type: "action",
        icon_class: "fa-solid fa-credit-card",
        color_class: "orange",
        hidden: ->(_event) { false },
        seed_if: ->(event) { event.cost_cents.to_i.positive? }
      },
      {
        magic_key: "certificate",
        title: "Certificate of completion",
        subtitle: "View and download your certificate",
        callout_type: "action",
        icon_class: "fa-solid fa-certificate",
        color_class: "green",
        # Off by default except on facilitator trainings; admins opt other events
        # in. When shown, it still only appears once the certificate unlocks.
        hidden: ->(event) { !event.facilitator_training? }
      },
      {
        magic_key: "scholarship",
        title: "Scholarship",
        subtitle: "Your scholarship request and award",
        callout_type: "action",
        icon_class: "fa-solid fa-award",
        # Colour (fuchsia) comes from the live card via #card_for, not a swatch.
        hidden: ->(_event) { false },
        seed_if: ->(event) { event.scholarship_form.present? }
      },
      {
        magic_key: "ce_hours",
        title: "CE hours",
        subtitle: "Continuing education — requirements & how to request",
        callout_type: "action",
        icon_class: "fa-solid fa-graduation-cap",
        # Colour (teal) comes from the live card via #card_for, not a swatch.
        # Content (label + details) stays on the event and is edited in the
        # callouts section's built-in card; the row only governs order/drip.
        hidden: ->(_event) { false },
        seed_if: ->(event) { event.ce_hours_offered.present? }
      },
      {
        magic_key: "event_details",
        title: "Before you attend",
        subtitle: "Important info for this event — please read",
        callout_type: "reference",
        icon_class: "fa-solid fa-palette",
        color_class: "blue",
        # Content (label + body) stays on the event and is edited in the built-in
        # card; the row only governs order/drip.
        hidden: ->(_event) { false },
        seed_if: ->(event) { event.event_details.present? }
      },
      {
        magic_key: "videoconference",
        title: "Videoconference",
        subtitle: "Join link and how to add it to your calendar",
        callout_type: "action",
        icon_class: "fa-solid fa-video",
        color_class: "blue",
        hidden: ->(_event) { false },
        # Drips onto the ticket a week before the event starts, replacing the old
        # hard-coded "one week prior" rule with a stored, editable date.
        display_from: ->(event) { event.start_date - 7.days if event.start_date },
        seed_if: ->(event) { event.videoconference_url.present? }
      },
      {
        magic_key: "forms",
        title: "Forms",
        subtitle: "W-9, invoice, and receipt",
        callout_type: "action",
        icon_class: "fa-solid fa-file-lines",
        color_class: "blue",
        hidden: ->(_event) { false },
        seed_if: ->(event) { event.show_forms_callout? }
      },
      {
        magic_key: "handouts",
        title: "Handouts",
        subtitle: "Worksheets and resources for the training",
        callout_type: "reference",
        icon_class: "fa-solid fa-folder-open",
        color_class: "blue",
        hidden: ->(event) { !event.show_handouts_callout? },
        resources: -> { handout_resources }
      },
      {
        magic_key: "faq",
        title: "Frequently asked questions",
        subtitle: "Common questions about the 2-day training",
        callout_type: "reference",
        icon_class: "fa-solid fa-circle-question",
        color_class: "blue",
        description: faq_html,
        hidden: ->(event) { !event.show_faq_callout? }
      }
    ]
  end

  def create(definition)
    callout = @event.registration_ticket_callouts.create!(
      magic_key: definition[:magic_key],
      title: definition[:title],
      subtitle: definition[:subtitle],
      description: definition[:description],
      callout_type: definition[:callout_type],
      icon_class: definition[:icon_class],
      color_class: definition[:color_class],
      hidden: definition[:hidden].call(@event),
      display_from: definition[:display_from]&.call(@event)
    )
    definition[:resources]&.call&.each { |resource| callout.resources << resource }
    callout
  end

  # The training worksheet resources, by title, in the display order the code
  # card used. Missing ones (not seeded in an environment) are simply skipped.
  def handout_resources
    by_title = Resource.where(title: Events::CalloutsController::HANDOUT_RESOURCE_TITLES).index_by(&:title)
    Events::CalloutsController::HANDOUT_RESOURCE_TITLES.filter_map { |title| by_title[title] }
  end

  # Renders FAQS to the basic HTML the callout description accepts (headings,
  # paragraphs, lists) so the materialized card reads like the code-defined page.
  def faq_html
    FAQS.map do |faq|
      parts = [ "<h3>#{h(faq[:q])}</h3>" ]
      parts += faq[:a].map { |paragraph| "<p>#{h(paragraph)}</p>" }
      parts << "<ul>#{faq[:list].map { |item| "<li>#{h(item)}</li>" }.join}</ul>" if faq[:list]
      parts.join
    end.join
  end

  def h(text)
    ERB::Util.html_escape(text)
  end
end
