require "set"

module OrganizationServices
  # Surfaces likely-duplicate organizations for the deduper's candidate list.
  #
  # Organizations are compared on a token key built by .tokens, which folds away
  # everything that varies between two spellings of one name: case, punctuation,
  # an ampersand, a legal suffix (Inc/LLC/Foundation/...), a trailing parenthetical
  # ("(SAFV)", "(California)"), the old app's trailing audience word ("Children's",
  # "Combined"), a trailing FileMaker code, "St." vs "Saint", plurals, and the filler
  # words the/of/and. That key is compared three ways — words sorted, words in order,
  # words run together — so word order and spacing (T.E.S.S.A. vs TESSA) don't
  # separate two orgs.
  #
  # On top of the name, groups are joined by a shared FileMaker code (one FileMaker
  # record whose programs landed on several rows), a leading-words relationship
  # ("Valley Oasis" / "Valley Oasis - Kaylas Place"), a single missing letter
  # (typos — the database's unique name index means a true duplicate can only
  # differ in spelling), the staff's own markings (a "Do Not Use"/"DELETE" row, and
  # RETIRED_DUPLICATE_OF), and — read from the FileMaker archive — a shared phone
  # number or website domain.
  #
  # Deliberately NOT compared: addresses (two orgs in one building are not
  # duplicates, and the portal holds almost no org addresses), and the 16 FileMaker
  # ParentID pairs, which are nesting work (one organization's programs) rather than
  # merges.
  #
  # Every group carries the section it belongs in (see TIERS) so the index can
  # present the queue strongest-signal-first, and its records are ordered so the
  # first one is the best suggestion for what to keep.
  class DuplicateFinder
    Group = Struct.new(:key, :label, :records, :reasons, :tier, keyword_init: true)

    # Section headings for the dedupe index, strongest signal first. A group's tier
    # is the first reason that explains it, so a card matching several signals is
    # filed under the one an admin should trust most.
    TIERS = {
      staff: "Staff already marked these as duplicates",
      spelling: "Same name, different spelling",
      typo: "Missing letters or a typo",
      program: "One organization, several program rows",
      other: "Matching phone or website"
    }.freeze

    TIER_ORDER = TIERS.keys.freeze

    REASON_TIERS = {
      "Staff marked one Do Not Use" => :staff,
      "Staff declared one a duplicate" => :staff,
      "Same name, different spelling" => :spelling,
      "Different place or alias in parentheses" => :spelling,
      "Missing letters or a typo" => :typo,
      "One name begins the other" => :program,
      "Same FileMaker record" => :program,
      "Same phone number" => :other,
      "Same website" => :other
    }.freeze

    LEGAL_SUFFIX = /\b(?:incorporated|inc|llc|l\.l\.c|corporation|corp|company|co|limited|ltd|foundation|associations?|assn|society|institute|ministries|ministry|dba)\b\.?/i

    # Organizations staff retired in the old app by renaming them. The marker says the
    # row duplicates another, so it only ever folds into its clean-named twin.
    DEAD_MARKER = /\b(?:do not use|created in error(?: cannot delete)?|delete)\b/i

    # Trailing audience descriptors that distinguish programs for the same org
    # (e.g. "… Children's" vs "… Adult"); ignored at the end of a name for matching.
    # Apostrophes are already stripped, so "children's" arrives as "childrens".
    # Shared with OrganizationServices::FilemakerNames, so its meaning (the old app's
    # audience versions) is left as it was — the wider set the deduper also folds
    # away lives in PROGRAM_WORDS.
    AUDIENCE_WORDS = %w[combined childrens children adult adults womens mens].freeze

    # Trailing program words the deduper folds away too. Youth and Teens end real
    # names ("Safe Place for Youth"), so they only count as a program word here,
    # where a wrong match merely adds a candidate.
    PROGRAM_WORDS = (AUDIENCE_WORDS + %w[youth teens]).freeze

    # Words that carry no identity, so two names differing only by them are one name.
    FILLER_WORDS = %w[the of and].freeze

    ABBREVIATIONS = { "st" => "saint", "mt" => "mount", "ft" => "fort", "ctr" => "center", "centre" => "center" }.freeze

    # A FileMaker org or project code as a name word, once punctuation is stripped:
    # "Hope Center (ORG00001)" ends in "org00001".
    FILEMAKER_CODE_WORD = /\A(?:org|p)\d{4,}\z/

    # A leading phrase on more names than this is a place or a common phrase
    # ("Los Angeles" is on 83 org names), not one organization's program prefix.
    # Without it, every org named after a city collapses into one card.
    COMMON_PHRASE_LIMIT = 45

    TRAILING_PARENTHETICAL = /\s*\(([^)]*)\)\s*\z/

    # Every name key is built from the same tokens, so a match is always a whole-word
    # match. Compared as-is (order preserved), sorted (order ignored), and run together
    # (spacing ignored).
    KEY_METHODS = %i[ordered sorted packed].freeze

    def self.normalized_name(name)
      name.to_s.downcase.gsub(/['’]/, "").gsub(/[^a-z0-9 ]/, " ").squish
    end

    def self.suffixless_name(name)
      normalized_name(name).gsub(LEGAL_SUFFIX, "").squish
    end

    # The words that decide whether two names are the same, with every variable part
    # folded away. Only for matching — stored names keep their own spelling.
    def self.tokens(name)
      value = name.to_s.downcase.gsub(/í(?=s\b)/, "").gsub(/['’]/, "").gsub("&", " and ")
      value = value.gsub(/[^a-z0-9]/, " ").squish
      value = value.sub(DEAD_MARKER, " ").squish
      value = value.gsub(LEGAL_SUFFIX, " ").squish
      value = strip_trailing_parentheticals(value)

      words = value.split
      words.pop while words.size > 1 && trailing_noise?(words.last)
      words.map { |word| ABBREVIATIONS.fetch(word, word) }
           .map { |word| word.sub(/\A(\d+)(?:st|nd|rd|th)\z/, "\\1") }
           .map { |word| singular(word) }
           .reject { |word| FILLER_WORDS.include?(word) }
    end

    def self.strip_trailing_parentheticals(value)
      loop do
        shorter = value.sub(TRAILING_PARENTHETICAL, "").squish
        return value if shorter == value

        value = shorter
      end
    end

    def self.trailing_noise?(word)
      PROGRAM_WORDS.include?(word) || word.match?(FILEMAKER_CODE_WORD)
    end

    # Enough to let "Safe Harbor" and "Safe Harbors" match; not a real inflector.
    # Both sides of a comparison run through it, so a word it mangles still matches
    # itself.
    def self.singular(word)
      word.length > 3 ? word.sub(/s\z/, "") : word
    end

    def initialize(scope = Organization.all)
      @organizations = scope.to_a
      @by_id = @organizations.index_by(&:id)
      @by_code = Hash.new { |hash, key| hash[key] = [] }
      @tokens = {}
      @word_counts = Hash.new(0)
      @organizations.each do |org|
        org.filemaker_codes.each { |code| @by_code[code] << org }
        tokens_for(org).uniq.each { |word| @word_counts[word] += 1 }
      end
      @parentheticals = {}
      @archive_available = archive_tables?
    end

    def groups
      union = UnionFind.new(@organizations.map(&:id))

      link_names(union)
      link_typos(union)
      link_programs(union)
      link_filemaker(union)
      link_phones(union)
      link_websites(union)
      link_declared_duplicates(union)

      union.components
           .filter_map { |ids| grouped(ids) }
           .sort_by { |tier, group| [ TIER_ORDER.index(tier), group.label.to_s.downcase ] }
           .map(&:last)
    end

    private

    def grouped(ids)
      return if ids.size < 2
      return if ids.size == 2 && parent_and_child?(ids[0], ids[1])

      records = ids.map { |id| @by_id[id] }.sort_by { |org| keeper_order(org) }
      reasons = reasons_for(records)
      tier = REASON_TIERS.fetch(reasons.first, :other)

      [ tier, Group.new(key: records.map(&:id).join("-"), label: records.first.name, records:, reasons:,
                        tier: TIERS.fetch(tier)) ]
    end

    # --- joining -------------------------------------------------------------------

    # One bucket per key: everything in a bucket is one spelling of one name.
    def link_names(union)
      buckets = Hash.new { |hash, key| hash[key] = [] }
      @organizations.each do |org|
        words = tokens_for(org)
        next if words.empty?

        KEY_METHODS.each { |method| buckets[name_key(words, method)] << org.id }
      end
      buckets.each_value { |ids| union.union_all(ids) if ids.size > 1 }
    end

    def link_typos(union)
      buckets = Hash.new { |hash, key| hash[key] = [] }
      @organizations.each do |org|
        words = tokens_for(org)
        next if words.size < 2

        key = name_key(words, :ordered)
        next if key.length < 6

        buckets[[ key[0], key[-1] ]] << [ org.id, key ]
      end

      buckets.each_value do |entries|
        entries.combination(2) do |(a, left), (b, right)|
          next if (left.length - right.length).abs > 1

          union.union_all([ a, b ]) if one_edit_apart?(left, right)
        end
      end
    end

    # "Valley Oasis" holds every leading word of "Valley Oasis - Kaylas Place", so the
    # longer name is a program row of the shorter one. Blocked on the rarer shared word
    # so this stays linear rather than every-org-against-every-org.
    def link_programs(union)
      index = Hash.new { |hash, key| hash[key] = [] }
      @organizations.each do |org|
        tokens_for(org).uniq.each { |word| index[word] << org.id }
      end

      @organizations.each do |org|
        words = tokens_for(org)
        next if words.size < 2

        index[words.min_by { |word| index[word].size }].each do |other_id|
          next if other_id == org.id
          next unless program_pair?(org.id, other_id)

          union.union_all([ org.id, other_id ])
        end
      end
    end

    # One FileMaker record whose programs landed on several portal rows.
    def link_filemaker(union)
      @by_code.each_value { |orgs| union.union_all(orgs.map(&:id)) if orgs.size > 1 }
    end

    def link_phones(union)
      buckets = Hash.new { |hash, key| hash[key] = [] }
      @organizations.each do |org|
        phones_for(org).each { |number| buckets[number] << org.id }
      end
      buckets.each_value { |ids| union.union_all(ids) if ids.size > 1 }
    end

    def link_websites(union)
      buckets = Hash.new { |hash, key| hash[key] = [] }
      @organizations.each do |org|
        domain = website_domain(org)
        buckets[domain] << org.id if domain
      end
      buckets.each_value { |ids| union.union_all(ids) if ids.size > 1 }
    end

    # The old app's own verdict: these two codes are one organization.
    def link_declared_duplicates(union)
      FilemakerValues::RETIRED_DUPLICATE_OF.each do |retired, survivor|
        retired_orgs = @by_code.fetch(retired, [])
        survivor_orgs = @by_code.fetch(survivor, [])
        next if retired_orgs.empty? || survivor_orgs.empty?

        retired_orgs.each do |left|
          survivor_orgs.each do |right|
            union.union_all([ left.id, right.id ]) unless left.id == right.id
          end
        end
      end
    end

    # --- naming --------------------------------------------------------------------

    def tokens_for(org)
      @tokens[org.id] ||= self.class.tokens(org.name)
    end

    def name_key(words, method)
      case method
      when :sorted then words.sort.join(" ")
      when :packed then words.join("")
      else words.join(" ")
      end
    end

    # The words in a trailing parenthetical the token key ignores, so a difference
    # ("(California)" vs "(Indiana)") can still be reported as a qualifier rather
    # than passed off as the same name.
    def parenthetical_for(org)
      return @parentheticals[org.id] if @parentheticals.key?(org.id)

      value = org.name.to_s.squish
      found = []
      while (match = value.match(TRAILING_PARENTHETICAL))
        found.unshift(match[1].squish)
        value = match.pre_match
      end
      @parentheticals[org.id] = found.join(" ").presence
    end

    def one_edit_apart?(left, right)
      return false if left == right

      if left.length == right.length
        differences = left.chars.zip(right.chars).reject { |a, b| a == b }
        return false unless differences.size == 1
        return false if differences.all? { |a, b| a.match?(/\d/) && b.match?(/\d/) }

        true
      elsif (left.length - right.length).abs == 1
        shorter, longer = left.length < right.length ? [ left, right ] : [ right, left ]
        index = 0
        index += 1 while index < shorter.length && shorter[index] == longer[index]
        return false unless shorter[index..] == longer[(index + 1)..]

        !longer[index].match?(/\d/)
      else
        false
      end
    end

    def program_pair?(id, other_id)
      return false if parent_and_child?(id, other_id)

      shorter, longer = [ tokens_for(@by_id[id]), tokens_for(@by_id[other_id]) ].sort_by(&:size)
      return false if shorter.size < 2 || shorter == longer
      return false unless longer.first(shorter.size) == shorter

      # At least one word must be distinctive, or "Los Angeles" / "Children's" would
      # swallow every org named after the place.
      shorter.map { |word| @word_counts[word] }.min <= COMMON_PHRASE_LIMIT
    end

    # --- FileMaker archive ---------------------------------------------------------

    def archive_tables?
      FmOrganization.table_exists? && FmPhoneNumber.table_exists?
    end

    def phones_for(org)
      return [] unless @archive_available

      org.filemaker_codes.flat_map { |code| phones_by_org_code.fetch(code, []).to_a }.uniq
    end

    def phones_by_org_code
      @phones_by_org_code ||= FmPhoneNumber.pluck(:data).each_with_object(Hash.new { |hash, key| hash[key] = Set.new }) do |data, numbers|
        code = data["OrgID"].to_s
        number = comparable_phone(data["PhoneNumber"])
        numbers[code] << number if code.present? && number
      end
    end

    def comparable_phone(value)
      digits = value.to_s.gsub(/\D/, "")
      digits = digits.delete_prefix("1") if digits.length == 11
      digits if digits.length >= 10
    end

    def website_domain(org)
      value = org.website_url.to_s.downcase.strip
      return if value.blank?

      value = value.sub(%r{\A[a-z]+://}, "").sub(/\Awww\./, "")
      domain = value.split("/").first.to_s
      domain if domain.include?(".")
    end

    # --- FileMaker hierarchy -------------------------------------------------------

    # ParentID marks an organization's own programs (Human Options, PROTOTYPES). Those
    # rows need nesting, not merging, so they are kept out of the queue entirely.
    def parent_and_child?(left_id, right_id)
      left = @by_id[left_id].filemaker_codes
      right = @by_id[right_id].filemaker_codes
      return false if left.empty? || right.empty?

      left.any? { |code| (parent_of[code] && right.include?(parent_of[code])) } ||
        right.any? { |code| (parent_of[code] && left.include?(parent_of[code])) }
    end

    def parent_of
      @parent_of ||= if FmOrganization.table_exists?
        FmOrganization.pluck(:fm_id, :data).each_with_object({}) do |(code, data), parents|
          parent = data["ParentID"].to_s.strip
          parents[code] = parent if parent.present?
        end
      else
        {}
      end
    end

    # --- why they were grouped -----------------------------------------------------

    def reasons_for(records)
      reasons = []
      reasons << "Staff marked one Do Not Use" if records.any? { |org| dead_marked?(org) }
      reasons << "Staff declared one a duplicate" if declared_duplicate?(records)

      words = records.map { |org| tokens_for(org) }
      if records.size > 1 && KEY_METHODS.any? { |method| words.map { |w| name_key(w, method) }.uniq.size == 1 }
        reasons << "Same name, different spelling"
      end
      if records.filter_map { |org| parenthetical_for(org) }.uniq.size > 1
        reasons << "Different place or alias in parentheses"
      end
      reasons << "Missing letters or a typo" if any_pair?(records) { |a, b| one_edit_apart?(name_key(tokens_for(a), :ordered), name_key(tokens_for(b), :ordered)) }
      reasons << "One name begins the other" if any_pair?(records) { |a, b| program_pair?(a.id, b.id) }
      reasons << "Same FileMaker record" if shared_filemaker_code?(records)
      reasons << "Same phone number" if shared_key?(records) { |org| phones_for(org) }
      reasons << "Same website" if shared_key?(records) { |org| Array(website_domain(org)) }

      reasons
    end

    def any_pair?(records, &block)
      records.combination(2).any? { |left, right| block.call(left, right) }
    end

    def shared_key?(records)
      keys = records.flat_map { |org| Array(yield(org)) }
      keys.tally.any? { |_key, count| count > 1 }
    end

    def shared_filemaker_code?(records)
      shared_key?(records, &:filemaker_codes)
    end

    def dead_marked?(org)
      org.name.to_s.match?(DEAD_MARKER)
    end

    def declared_duplicate?(records)
      codes = records.flat_map(&:filemaker_codes).to_set
      FilemakerValues::RETIRED_DUPLICATE_OF.any? { |retired, survivor| codes.include?(retired) && codes.include?(survivor) }
    end

    # --- which one to keep ---------------------------------------------------------

    # Never suggest a dead row; then the base organization over its program rows; then
    # the record FileMaker created first (the original, before it was re-added); then
    # the oldest portal row.
    def keeper_order(org)
      [ dead_marked?(org) ? 1 : 0,
        name_key(tokens_for(org), :ordered).length,
        filemaker_created_at(org) || portal_created_at(org),
        org.id ]
    end

    def filemaker_created_at(org)
      return unless @archive_available

      org.filemaker_codes.filter_map { |code| filemaker_creation_dates[code] }.min
    end

    def filemaker_creation_dates
      @filemaker_creation_dates ||= FmOrganization.pluck(:fm_id, :data).each_with_object({}) do |(code, data), dates|
        created = data["CreationDate"].to_s
        dates[code] = created if created.present?
      end
    end

    def portal_created_at(org)
      org.created_at&.strftime("%Y-%m-%d %H:%M:%S").to_s
    end
  end
end
