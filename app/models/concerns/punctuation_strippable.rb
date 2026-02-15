# frozen_string_literal: true

module PunctuationStrippable
  extend ActiveSupport::Concern

  module ClassMethods
    # Returns a SQL fragment that strips punctuation from a field
    # Removes: hyphens, ampersands, periods, em/en dashes, and various quote types
    def strip_punctuation_sql(field_name)
      # 11 nested REPLACE calls for 11 punctuation characters
      "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(" \
      "#{field_name}, " \
      "'-', ''), '&', ''), '.', ''), '—', ''), '–', ''), " \
      "'\"', ''), \"'\", ''), ''', ''), ''', ''), '"', ''), '"', '')"
    end

    # Strips punctuation from a string using Ruby
    # Removes the same characters as strip_punctuation_sql
    def strip_punctuation(text)
      text.to_s.gsub(/[-&.—–'"''""]/, "")
    end
  end
end
