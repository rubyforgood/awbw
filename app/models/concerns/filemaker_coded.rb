# FileMaker is the source of truth, and one record can answer to more than one
# FileMaker code — two records that each mapped to a FileMaker row get merged, or the
# archive itself holds several rows for one person. The `filemaker_code` column holds
# them as a trimmed, comma-separated list; this is the seam for reading and combining
# them, so nothing compares the whole column against a single code.
module FilemakerCoded
  extend ActiveSupport::Concern

  def filemaker_codes
    self.class.split_filemaker_codes(filemaker_code)
  end

  class_methods do
    def split_filemaker_codes(value)
      value.to_s.split(",").map(&:strip).reject(&:blank?).uniq
    end

    # A single normalized column value from any mix of code strings/lists.
    def join_filemaker_codes(*values)
      values.flatten.flat_map { |value| split_filemaker_codes(value) }.uniq.sort.join(", ").presence
    end
  end
end
