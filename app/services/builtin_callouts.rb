# The catalog of built-in ticket callouts (Payment, Certificate, Scholarship, CE
# hours, Event details, Videoconference, Handouts, FAQ) and the code that
# materializes them onto an event as editable RegistrationTicketCallout rows:
# `seed` persists them (on create, and lazily on edit so older events heal with no
# backfill); `build` makes the same rows in memory for the new-event form; `reset`
# restores a row to its default; `customized?` reports whether a row was edited.
#
# All eight seed hidden (unchecked) by default — admins publish the ones they want
# per event, edit them per row, and can restore a row to default. Custom callouts
# live in the same list and can be reordered among the built-ins. Seeding is
# idempotent so a re-run never clobbers admin edits.
#
# This service owns the callouts' *definitions and materialization*. How a callout
# then renders as a live card on a registrant's ticket (status badges, per-
# registration guards) is the job of BuiltinCalloutCards.
class BuiltinCallouts
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

  # Hidden Resource (by title) backing the handout links, in display order.
  # Missing ones (e.g. not seeded in an environment) are silently skipped.
  HANDOUT_RESOURCE_TITLES = [
    "2-Day AWBW Facilitator Training Worksheets & Handouts",
    "AWBW Training Workshop Worksheets",
    "Aha Moments",
    "Inviting and Responding to Participants' Sharing",
    "Letter to Supervisors"
  ].freeze

  # Default per-resource copy for the built-in handout links, keyed by resource
  # title. `subtitle` is the short line on the handouts card; `page_content` is
  # the longer copy shown under the title on the resource's own page. Materialized
  # onto each join row so admins edit it per event (previously hard-coded in
  # Events::CalloutsController::HANDOUT_SUBTITLES and rendered from there).
  HANDOUT_LINK_DEFAULTS = {
    "2-Day AWBW Facilitator Training Worksheets & Handouts" => {
      subtitle: "Worksheets we'll reference throughout the training",
      page_content: "List of resources and worksheets we will reference and utilize during the training. You do not need to print them out, it may be helpful for you to access the links during the training."
    },
    "AWBW Training Workshop Worksheets" => {
      subtitle: "Create-along worksheets for the five art workshops",
      page_content: "Worksheets you can create on during all 5 of the art workshops at the training. Any art materials are welcomed during creation."
    },
    "Aha Moments" => {
      subtitle: "Reflect on the workshop and its impact",
      page_content: "Worksheet you can use to reflect on the workshop, its impact, and how you'd like to apply it."
    },
    "Inviting and Responding to Participants' Sharing" => {
      subtitle: "Support sharing and connection in breakout rooms",
      page_content: "A resource to invite and support sharing, active listening, and connection during breakout rooms."
    },
    "Letter to Supervisors" => {
      subtitle: "Secure the time and space to fully engage",
      page_content: "Letter you can share to help relieve you from competing responsibilities during the two training days. So you can secure the time and space needed to fully engage in the training."
    }
  }.freeze

  def self.seed(event)
    new(event).seed
  end

  # Build (not persist) any not-yet-present built-in callouts as in-memory rows on
  # the event, so a brand-new event's form shows the built-ins as editable rows
  # that save together with the event on first submit. Idempotent against rows
  # already loaded/built (e.g. re-rendering a failed create), so it never
  # duplicates. Persisting still routes each row's `builtin_key` back through nested
  # attributes; the post-save `seed` is the idempotent safety net for non-form
  # creation paths. Returns the built rows.
  def self.build(event)
    new(event).build
  end

  # Reset a materialized callout's content and default visibility back to its
  # built-in template, keeping its position. Used by the "Restore default" action.
  def self.reset(callout)
    new(callout.event).reset(callout)
  end

  # Whether a materialized callout has been edited away from its built-in
  # template, so the editor can offer "Restore default" only when it applies.
  def self.customized?(callout)
    new(callout.event).customized?(callout)
  end

  def initialize(event)
    @event = event
  end

  # Create any not-yet-present built-in callouts for the event, appended in
  # definition order after whatever already exists. All built-ins always seed;
  # their initial visibility (hidden/published) is derived from the event's
  # config via each definition's `hidden` proc. Seeding is idempotent so a re-run
  # never clobbers admin edits. Returns the created rows.
  def seed
    existing_keys = @event.registration_ticket_callouts.builtin.pluck(:builtin_key).to_set
    definitions.reject { |definition| existing_keys.include?(definition[:builtin_key]) }
               .filter_map { |definition| create(definition) }
  end

  # In-memory counterpart to #seed. Skips keys already present on the loaded
  # association (built or persisted) so it's safe to call on every form render.
  def build
    existing_keys = @event.registration_ticket_callouts.reject(&:marked_for_destruction?).filter_map(&:builtin_key).to_set
    definitions.reject { |definition| existing_keys.include?(definition[:builtin_key]) }
               .map { |definition| build_row(definition) }
  end

  def reset(callout)
    definition = definitions.find { |candidate| candidate[:builtin_key] == callout.builtin_key }
    return callout unless definition

    callout.update!(
      title: resolve(definition[:title]),
      subtitle: resolve(definition[:subtitle]),
      description: resolve(definition[:description]),
      callout_type: definition[:callout_type],
      icon_class: definition[:icon_class],
      color_class: definition[:color_class],
      hidden: definition[:hidden].call(@event),
      display_from: definition[:display_from]&.call(@event)
    )
    callout.registration_ticket_callout_resources.destroy_all
    build_resource_links(callout, definition)
    callout
  end

  def customized?(callout)
    definition = definitions.find { |candidate| candidate[:builtin_key] == callout.builtin_key }
    return false unless definition

    callout.title != resolve(definition[:title]) ||
      callout.subtitle != resolve(definition[:subtitle]) ||
      callout.description.to_s != resolve(definition[:description]).to_s ||
      callout.callout_type != definition[:callout_type] ||
      callout.icon_class != definition[:icon_class] ||
      callout.color_class != definition[:color_class] ||
      callout.hidden != definition[:hidden].call(@event) ||
      callout.display_from != definition[:display_from]&.call(@event) ||
      callout.resource_ids.sort != Array(definition[:resources]&.call).map(&:id).sort ||
      resource_content_customized?(callout, definition)
  end

  private

  # A definition value may be a static value or a proc taking the event (used by
  # CE / event details to seed their default from the event's own columns).
  def resolve(value)
    value.respond_to?(:call) ? value.call(@event) : value
  end

  # Ordered built-in callout definitions. `hidden` / `display_from` are procs so
  # each event derives its own defaults; `resources` resolves the linked records;
  # `seed_if` gates whether the card applies. Content cards (Handouts, FAQ) render
  # their own copy; "behavioral" cards (Certificate, Videoconference) render live
  # per-registration status through BuiltinCalloutCards#card_for — the row only
  # governs visibility, drip date, and order.
  def definitions
    [
      {
        builtin_key: "payment",
        title: "Payment",
        subtitle: "Your balance and payment history",
        callout_type: "action",
        icon_class: "fa-solid fa-credit-card",
        color_class: "orange",
        hidden: ->(_event) { true },
        # The W-9 is a removable linked resource, included by default only on paid
        # events (where a tax form applies); the invoice/receipt stay dynamic on
        # the payment page. Admins add/remove it per event.
        resources: -> { @event.cost_cents.to_i.positive? ? [ Resource.find_by(title: "W-9") ].compact : [] },
        # Its card subtitle is materialized here (admin-editable), not hard-coded in the view.
        resource_content: {
          "W-9" => { subtitle: "AWBW's W-9 tax form for your records" }
        }
      },
      {
        builtin_key: "certificate",
        title: "Certificate of completion",
        subtitle: "View and download your certificate",
        callout_type: "action",
        icon_class: "fa-solid fa-certificate",
        color_class: "green",
        # Off by default except on facilitator trainings. When shown, it still only
        # appears once the certificate unlocks (BuiltinCalloutCards guards this).
        hidden: ->(_event) { true }
      },
      {
        builtin_key: "scholarship",
        title: "Scholarship",
        subtitle: "Your scholarship request and award",
        callout_type: "action",
        icon_class: "fa-solid fa-award",
        color_class: "fuchsia",
        hidden: ->(_event) { true }
      },
      {
        builtin_key: "ce_hours",
        # Title/text live on the row like every other built-in; admins fill in the
        # CE requirements copy per event. The row also carries the CE
        # hours-offered/cost config.
        title: "CE hours",
        subtitle: "Continuing education — requirements & how to request",
        callout_type: "action",
        icon_class: "fa-solid fa-graduation-cap",
        color_class: "teal",
        hidden: ->(_event) { true }
      },
      {
        builtin_key: "art_supplies",
        # A content callout: renders its own editable copy on the generic callout
        # page. Admins add the "what to bring" details per event.
        title: "Art supplies & what to bring",
        subtitle: "Important info for this event — please read",
        callout_type: "reference",
        icon_class: "fa-solid fa-palette",
        color_class: "blue",
        hidden: ->(_event) { true }
      },
      {
        builtin_key: "videoconference",
        title: "Videoconference",
        subtitle: "Join link and how to add it to your calendar",
        callout_type: "action",
        icon_class: "fa-solid fa-video",
        color_class: "blue",
        hidden: ->(_event) { true },
        # Default drip date; admins can edit it per event afterward.
        display_from: ->(event) { event.start_date - 7.days if event.start_date }
      },
      {
        builtin_key: "handouts",
        title: "Handouts",
        subtitle: "Worksheets and resources for the training",
        callout_type: "reference",
        icon_class: "fa-solid fa-folder-open",
        color_class: "blue",
        hidden: ->(_event) { true },
        resources: -> { handout_resources },
        # Per-link subtitle/page_content defaults, keyed by resource title.
        resource_content: HANDOUT_LINK_DEFAULTS
      },
      {
        builtin_key: "faq",
        title: "Frequently asked questions",
        subtitle: "Common questions about the 2-day training",
        callout_type: "reference",
        icon_class: "fa-solid fa-circle-question",
        color_class: "blue",
        description: self.class.faq_html,
        hidden: ->(_event) { true }
      }
    ]
  end

  def create(definition)
    callout = @event.registration_ticket_callouts.create!(attributes_for(definition))
    build_resource_links(callout, definition)
    callout
  rescue ActiveRecord::RecordNotUnique
    # A concurrent request seeded this built-in in the window between our existence
    # check and this insert, so the unique index on [event_id, builtin_key] rejects
    # the duplicate. Seeding is idempotent, so drop the failed in-memory row and skip.
    @event.registration_ticket_callouts.reset
    nil
  end

  # In-memory sibling of #create: builds the row (and its resource links) without
  # persisting, so they save as nested attributes when the event is saved.
  def build_row(definition)
    callout = @event.registration_ticket_callouts.build(attributes_for(definition))
    build_resource_links(callout, definition)
    callout
  end

  def attributes_for(definition)
    {
      builtin_key: definition[:builtin_key],
      title: resolve(definition[:title]),
      subtitle: resolve(definition[:subtitle]),
      description: resolve(definition[:description]),
      callout_type: definition[:callout_type],
      icon_class: definition[:icon_class],
      color_class: definition[:color_class],
      hidden: definition[:hidden].call(@event),
      display_from: definition[:display_from]&.call(@event)
    }
  end

  # Link the definition's resources in order, materializing each join row's
  # subtitle/page_content from `resource_content` (keyed by resource title) when
  # the definition supplies it. Links persist immediately for a saved callout, or
  # stay in memory (saved with the event) when the callout is still unsaved. The
  # positioning gem assigns each row's position.
  def build_resource_links(callout, definition)
    content = definition[:resource_content] || {}
    Array(definition[:resources]&.call).each do |resource|
      attrs = content[resource.title] || {}
      link = callout.registration_ticket_callout_resources.build(
        resource: resource,
        subtitle: attrs[:subtitle],
        page_content: attrs[:page_content]
      )
      link.save! if callout.persisted?
    end
  end

  # Whether any link's subtitle/page_content has been edited away from its
  # default, so "Restore default" is offered when only the copy was changed.
  def resource_content_customized?(callout, definition)
    content = definition[:resource_content]
    return false if content.blank?

    callout.registration_ticket_callout_resources.any? do |link|
      defaults = content[link.resource.title]
      next false if defaults.blank?
      link.subtitle.to_s != defaults[:subtitle].to_s ||
        link.page_content.to_s != defaults[:page_content].to_s
    end
  end

  # The training worksheet resources, by title, in the display order the code
  # card used. Missing ones (not seeded in an environment) are simply skipped.
  def handout_resources
    by_title = Resource.where(title: HANDOUT_RESOURCE_TITLES).index_by(&:title)
    HANDOUT_RESOURCE_TITLES.filter_map { |title| by_title[title] }
  end

  # Renders FAQS to standard <details>/<summary> disclosures so each question is a
  # collapsible section, identical to how the FAQ page and every other callout
  # render admin-authored disclosures (see CalloutContent). Used both to seed the
  # materialized card's editable copy and as the FAQ page's fallback default, so a
  # fresh card starts as editable toggles.
  def self.faq_html
    FAQS.map do |faq|
      body = faq[:a].map { |paragraph| "<p>#{h(paragraph)}</p>" }
      body << "<ul>#{faq[:list].map { |item| "<li>#{h(item)}</li>" }.join}</ul>" if faq[:list]
      "<details><summary>#{h(faq[:q])}</summary>#{body.join}</details>"
    end.join
  end

  def self.h(text)
    ERB::Util.html_escape(text)
  end
end
