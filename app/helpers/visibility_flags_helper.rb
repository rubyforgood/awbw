module VisibilityFlagsHelper
  # Plain-language definitions for the publish/visibility checkboxes on the admin
  # portal edit forms. The copy mirrors what the Publishable and Featureable
  # scopes actually enforce (see app/models/concerns/publishable.rb and
  # featureable.rb) — note the dependency ladder: publicly visible requires
  # published, and publicly featured requires both. Keep them in sync.
  FLAG_DEFINITIONS = {
    published: {
      label: "Published",
      description: "Makes this visible to signed-in users. (Uncheck to keep it a staff-only draft.)"
    },
    featured: {
      label: "Featured",
      description: "Shows this on the homepage for signed-in users. (Requires Published to take effect.)"
    },
    publicly_visible: {
      label: "Publicly visible",
      description: "Makes this visible to any visitor who is not logged in. (Requires Published to take effect.)"
    },
    publicly_featured: {
      label: "Publicly featured",
      description: "Shows this on the homepage for visitors who are not logged in. (Requires both Published and Publicly visible to take effect.)"
    },
    hidden_from_search: {
      label: "Hidden from search",
      description: "Leaves this out of on-site search results. (Doesn't change the other flags; it stays reachable by direct link.)"
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
      description: "Lets the public register for this event without an AWBW account. (Requires Published and Publicly visible to take effect.)"
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
