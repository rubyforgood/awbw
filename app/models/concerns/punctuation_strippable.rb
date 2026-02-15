# frozen_string_literal: true

module PunctuationStrippable
  extend ActiveSupport::Concern

  module ClassMethods
    # Returns a SQL fragment that strips punctuation from a field
    # Removes: hyphens, ampersands, periods, em/en dashes, quotes, slashes,
    # colons, plus signs, exclamation/question marks, commas, parentheses, ellipsis
    def strip_punctuation_sql(field_name)
      # Each pair is [SQL character expression, replacement]
      # Use hex literals for Unicode and characters that conflict with SQL/AR syntax
      chars = [
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
      ]

      result = field_name
      chars.each { |c| result = "REPLACE(#{result}, #{c}, '')" }

      # Collapse multiple spaces into one (3 passes handles up to 8 consecutive spaces)
      3.times { result = "REPLACE(#{result}, '  ', ' ')" }
      result
    end

    # Strips punctuation from a string using Ruby
    # Removes the same characters as strip_punctuation_sql
    def strip_punctuation(text)
      text.to_s.gsub(/[-&.—–'"''""\/:+!?,()…]/, "").gsub(/\s+/, " ")
    end
  end
end
