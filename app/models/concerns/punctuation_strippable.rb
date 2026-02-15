# frozen_string_literal: true

module PunctuationStrippable
  extend ActiveSupport::Concern

  PUNCTUATION_CHARS_SQL = [
    "'-'",      # hyphen
    "'&'",      # ampersand
    "'.'",      # period
    "0xE28094", # em dash —
    "0xE28093", # en dash –
    "'\"'",     # double quote "
    "\"'\"",    # single quote '
    "0xE28098", # left single curly quote '
    "0xE28099", # right single curly quote '
    "0xE2809C", # left double curly quote "
    "0xE2809D", # right double curly quote "
    "'/'",      # slash
    "':'",      # colon
    "'+'",      # plus
    "'!'",      # exclamation
    "CHAR(63)", # question mark ?
    "','",      # comma
    "'('",      # open paren
    "')'",      # close paren
    "0xE280A6"  # ellipsis …
  ].freeze

  PUNCTUATION_REGEX = /[-&.—–'"''""\/:+!?,()…]/

  module ClassMethods
    # "spaced" — punctuation → space, collapse multiple spaces.
    # Matches "self care" to "self-care".
    def strip_punctuation_sql_spaced(field_name)
      result = normalize_synonyms_sql(field_name)
      PUNCTUATION_CHARS_SQL.each { |c| result = "REPLACE(#{result}, #{c}, ' ')" }
      3.times { result = "REPLACE(#{result}, '  ', ' ')" }
      result
    end

    # "spaceless" — punctuation AND spaces → removed entirely.
    # Matches "selfcare" to "self-care" and to "self care".
    def strip_punctuation_sql_spaceless(field_name)
      result = normalize_synonyms_sql(field_name)
      PUNCTUATION_CHARS_SQL.each { |c| result = "REPLACE(#{result}, #{c}, '')" }
      result = "REPLACE(#{result}, ' ', '')"
      result
    end

    def strip_punctuation_spaced(text)
      normalize_synonyms(text).gsub(PUNCTUATION_REGEX, " ").gsub(/\s+/, " ")
    end

    def strip_punctuation_spaceless(text)
      normalize_synonyms(text).gsub(PUNCTUATION_REGEX, "").gsub(/\s+/, "")
    end

    private

    # Normalize synonyms so both sides strip the same way.
    # " and " → " & " (then & gets stripped as punctuation)
    # "w/" → "with" (then / gets stripped, leaving "with" on both sides)
    def normalize_synonyms_sql(field_name)
      result = "REPLACE(#{field_name}, ' and ', ' & ')"
      "REPLACE(#{result}, 'w/', 'with')"
    end

    def normalize_synonyms(text)
      text.to_s.gsub(/ and /i, " & ").gsub(/w\//i, "with")
    end
  end
end
