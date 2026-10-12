# One record can answer to more than one FileMaker code — two records that each mapped
# to a FileMaker row get merged, or the archive itself holds several rows for one
# person. The `filemaker_code` column holds them as a sorted, comma-separated list;
# this is the seam for reading and combining them, so nothing compares the whole
# column against a single code. Codes never hold whitespace, so any (tabs, line
# breaks, pasted non-breaking spaces) is dropped.
module FilemakerCoded
  extend ActiveSupport::Concern

  included do
    class_attribute :filemaker_archives, instance_writer: false, default: []

    normalizes :filemaker_code, with: ->(value) { join_filemaker_codes(value) }, apply_to_nil: true
  end

  def filemaker_codes
    self.class.split_filemaker_codes(filemaker_code)
  end

  class_methods do
    # The Fm* archive tables this model's codes point into, checked in order.
    def filemaker_archived_in(*archives)
      self.filemaker_archives = archives
    end

    def with_filemaker_code(code)
      where("FIND_IN_SET(?, REGEXP_REPLACE(filemaker_code, '[[:space:]]', ''))", strip_filemaker_code(code))
    end

    def split_filemaker_codes(value)
      value.to_s.split(",").map { |code| strip_filemaker_code(code) }.reject(&:empty?).uniq
    end

    def strip_filemaker_code(code)
      code.to_s.gsub(/[[:space:]]/, "")
    end

    # A single normalized column value from any mix of code strings/lists.
    def join_filemaker_codes(*values)
      values.flatten.flat_map { |value| split_filemaker_codes(value) }.uniq.sort.join(", ").presence
    end
  end
end
