module VisibilityFlagsHelper
  # Plain-language definitions for the publish/visibility checkboxes on the admin
  # portal edit forms. The copy mirrors what the Publishable and Featureable
  # scopes actually enforce (see app/models/concerns/publishable.rb and
  # featureable.rb) — note the dependency ladder: publicly visible requires
  # published, and publicly featured requires both. Keep them in sync.
  FLAG_DEFINITIONS = {
    published: {
      label: "Published",
      description: "Makes this live in the member portal for signed-in AWBW members. Leave it off to keep it a draft that only staff can see."
    },
    featured: {
      label: "Featured",
      description: "Highlights this inside the member portal (shown first or pinned). Only takes effect when Published is on."
    },
    publicly_visible: {
      label: "Publicly visible",
      description: "Shows this on the public awbw.org website to anyone, no login needed. Requires Published to be on."
    },
    publicly_featured: {
      label: "Publicly featured",
      description: "Highlights this on the public website (e.g. featured on a landing page). Requires both Published and Publicly visible."
    },
    hidden_from_search: {
      label: "Hidden from search",
      description: "Keeps this reachable by direct link but leaves it out of on-site search results."
    },
    is_instructional: {
      label: "Instructional",
      description: "Marks this recording as instructional or how-to content."
    },
    is_podcast: {
      label: "Podcast",
      description: "Marks this recording as a podcast episode."
    },
    public_registration_enabled: {
      label: "Publicly registerable",
      description: "Lets the public register for this event without an AWBW account."
    }
  }.freeze

  # Renders a boolean visibility checkbox whose row is hoverable with its
  # plain-language definition. Passes through any extra simple_form options.
  def visibility_flag_input(form, flag, **options)
    definition = FLAG_DEFINITIONS[flag]
    wrapper_html = options.delete(:wrapper_html) || {}
    wrapper_html[:title] ||= definition[:description] if definition
    form.input flag, as: :boolean, wrapper_html: wrapper_html, **options
  end
end
