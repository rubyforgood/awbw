module VisibilityFlagsHelper
  # Plain-language copy for the publish/visibility checkboxes on the admin portal
  # forms. Each entry has a short `hint` (shown under the checkbox) and a longer
  # `description` (the hover title and the "i" popover text). The copy mirrors
  # what the Publishable/Featureable scopes enforce (app/models/concerns/
  # publishable.rb, featureable.rb) — note the dependency ladder: publicly
  # visible requires published, and publicly featured requires both.
  FLAG_DEFINITIONS = {
    published: {
      label: "Published",
      hint: "Visible to signed-in users",
      description: "Makes this visible to signed-in users. (Uncheck to keep it a staff-only draft.)"
    },
    featured: {
      label: "Featured",
      hint: "On the member homepage",
      description: "Shows this on the homepage for signed-in users. (Requires Published to take effect.)"
    },
    publicly_visible: {
      label: "Publicly visible",
      hint: "Visible to logged-out visitors",
      description: "Makes this visible to any visitor who is not logged in. (Requires Published to take effect.)"
    },
    publicly_featured: {
      label: "Publicly featured",
      hint: "On the public homepage",
      description: "Shows this on the homepage for visitors who are not logged in. (Requires both Published and Publicly visible to take effect.)"
    },
    hidden_from_search: {
      label: "Hidden from search",
      hint: "Hidden from search; link still works",
      description: "Hides this from search results while keeping the direct link working. (The link still needs Published for users, or Publicly visible for visitors.)"
    },
    is_instructional: {
      label: "Instructional",
      hint: "How-to / instructional content",
      description: "Marks this recording as instructional or how-to content."
    },
    is_podcast: {
      label: "Podcast",
      hint: "Podcast episode",
      description: "Marks this recording as a podcast episode."
    },
    public_registration_enabled: {
      label: "Publicly registerable",
      hint: "Public can register, no account",
      description: "Lets the public register for this event without a user account. (Requires Published and Publicly visible to take effect.)"
    },
    # Category types repurpose `published` to gate their child categories rather
    # than portal visibility, so they use this definition via definition_key.
    category_type_published: {
      label: "Published",
      hint: "Hides all child categories",
      description: "When off, this type and all of its child categories are hidden."
    },
    story_specific: {
      label: "Story specific",
      hint: "Needed for story share subsite",
      description: "Needed for the story share subsite."
    },
    profile_specific: {
      label: "Profile specific",
      hint: "Shown on person & organization forms",
      description: "Shown on the person and organization forms."
    }
  }.freeze

  # Renders a boolean flag checkbox with the shared copy: a short hint under the
  # box and the longer definition as a hover title. Pass definition_key: to use a
  # different entry than the attribute name (e.g. category type's published).
  # Any simple_form option (label, hint, input_html, wrapper_html) is honored and
  # overrides the defaults.
  def visibility_flag_input(form, flag, definition_key: flag, **options)
    definition = FLAG_DEFINITIONS[definition_key]
    wrapper_html = options.delete(:wrapper_html) || {}
    wrapper_html[:title] ||= definition[:description] if definition
    options[:hint] = definition[:hint] if definition && !options.key?(:hint)
    form.input flag, as: :boolean, wrapper_html: wrapper_html, **options
  end
end
