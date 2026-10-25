# The prefixed search behind every "find them by where they are" box — the people
# index, the attendees index, the organizations index. Typing `city: austin
# state: tx` narrows by each field; a bare term searches all of them. Defined once
# so a prefix reaches every box at the same moment and the help text beside them
# can't drift from what the search accepts.
#
# Prefixes are the vocabulary admins learn, so they're named for what someone
# would type rather than for the column: remap a renamed column here instead of
# retraining everyone.
module ContactSearchable
  extend ActiveSupport::Concern

  # "amy--aisha" is how this app says "either" everywhere else — tag filters, the
  # registrants roster, the bulk-email picker, workshop search. SearchCop spells
  # it `or`, so a query typed with `--` is rewritten before it gets there and the
  # one hint below is true of every search box in the app.
  ALTERNATIVE_SEPARATOR = "--".freeze

  # prefix => the column(s) it searches, in SearchCop's "table.column" form.
  # Deliberately wider than the location charts: street and phone don't group into
  # a chart, but they're exactly what someone has in hand when they're looking
  # someone up.
  CONTACT_SEARCH_FIELDS = {
    phone: [ "contact_methods.value", "addresses.phone" ],
    street: "addresses.street_address",
    city: "addresses.city",
    state: "addresses.state",
    zip: "addresses.zip_code",
    county: "addresses.county",
    country: "addresses.country",
    locality: "addresses.locality",
    district: "addresses.district",
    la_council: "addresses.la_city_council_district",
    la_supervisorial: "addresses.la_supervisorial_district",
    la_spa: "addresses.la_service_planning_area",
    # Narrows to one kind of address (work / personal / mailing). SearchCop ANDs
    # the prefixes onto the same joined row, so `type: personal city: austin` asks
    # for an address that is BOTH — the way to search a personal city alone.
    type: "addresses.address_type"
  }.freeze

  # Prefixes a bare term doesn't search. `type:` because "personal" is a word
  # people live on streets called, not a search for every personal address; the LA
  # districts because they're integer columns, so a bare term asking them for a
  # LIKE match would be asking a number to contain a word.
  SCOPING_PREFIXES = %i[ type la_council la_supervisorial la_spa ].freeze

  # The one help hint, shared by every search box so none of them can describe a
  # syntax the others don't take.
  SEARCH_SYNTAX_HINT = "Several words all have to match. Use -- for either (amy--aisha), quotes for a phrase.".freeze
  # `or` is SearchCop's own operator, so Oregon has to be asked for by prefix
  # (`state: OR`) rather than typed bare — worth saying in the box that takes
  # prefixes, not in the general hint.
  CONTACT_SEARCH_HINT = [
    "Prefixes: #{CONTACT_SEARCH_FIELDS.keys.map { |prefix| "#{prefix}:" }.join(', ')}.",
    "Several narrow to one address (type: personal city: austin).",
    SEARCH_SYNTAX_HINT,
    "Write Oregon as state: OR — a bare or means \"either\"."
  ].join(" ").freeze

  # The alternatives someone typed. A lone hyphenated value ("Smith-Jones") is one
  # alternative, not two — only the doubled separator splits.
  def self.alternatives(query)
    query.to_s.split(ALTERNATIVE_SEPARATOR).map(&:strip).compact_blank
  end

  # The same query in SearchCop's own grammar: each alternative parenthesised so
  # its words still AND together under the `or`, and commas spaced out so a pasted
  # "Austin, TX" reads as two words rather than one word ending in a comma. A
  # quoted query is left alone — the commas in it are part of the phrase.
  def self.expand_alternatives(query)
    parts = alternatives(query)
    parts = parts.map { |part| part.tr(",", " ").squeeze(" ").strip } unless query.to_s.include?('"')
    return parts.first.to_s if parts.one?

    parts.map { |part| "(#{part})" }.join(" or ")
  end

  class_methods do
    # Defines a prefixed search scope over the CONTACT_SEARCH_FIELDS that live on
    # the associations named here, so a model without one (an organization has
    # addresses but no contact methods) offers the prefixes it can answer. `as:`
    # names the scope, for a model that already has a search of its own to keep.
    def searches_contact(*associations, as: :search_contact)
      tables = associations.map { |association| reflect_on_association(association).table_name }
      fields = CONTACT_SEARCH_FIELDS.filter_map do |prefix, columns|
        reachable = Array(columns).select { |column| tables.include?(column.split(".").first) }
        [ prefix, reachable ] if reachable.any?
      end.to_h
      searched = fields.except(*SCOPING_PREFIXES).values.flatten

      search_scope :"#{as}_matches" do
        scope { left_joins(*associations) }
        fields.each { |prefix, columns| attributes prefix => columns }
        attributes all: searched
        # Several words narrow rather than widen — typing more should find less,
        # the way every search box people already use behaves. `--` says "either".
        options :all, type: :text, default: true, default_operator: :and
      end

      # Distinct here rather than at each call site: the joins mean an owner with
      # two matching addresses would otherwise arrive twice, and a caller that
      # forgets only finds out when a duplicate row reaches a page.
      matcher = :"#{as}_matches"
      scope as, ->(query) {
        expanded = ContactSearchable.expand_alternatives(query)
        expanded.blank? ? all : public_send(matcher, expanded).distinct
      }
    end
  end
end
