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
      result = field_name
      PUNCTUATION_CHARS_SQL.each { |c| result = "REPLACE(#{result}, #{c}, ' ')" }
      3.times { result = "REPLACE(#{result}, '  ', ' ')" }
      result
    end

    # "spaceless" — punctuation AND spaces → removed entirely.
    # Matches "selfcare" to "self-care" and to "self care".
    def strip_punctuation_sql_spaceless(field_name)
      result = field_name
      PUNCTUATION_CHARS_SQL.each { |c| result = "REPLACE(#{result}, #{c}, '')" }
      result = "REPLACE(#{result}, ' ', '')"
      result
    end

    def strip_punctuation_spaced(text)
      text.to_s.gsub(PUNCTUATION_REGEX, " ").gsub(/\s+/, " ")
    end

    def strip_punctuation_spaceless(text)
      text.to_s.gsub(PUNCTUATION_REGEX, "").gsub(/\s+/, "")
    end
  end
end
