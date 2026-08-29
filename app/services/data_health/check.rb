module DataHealth
  # Base for one data-consistency check on the admin Data health page.
  #
  # A check answers three things: which rows are wrong (`scope`), how to say that
  # in a sentence (`title` / `explanation`), and whether it can put them right
  # (`repairable?` / `repair!`). Everything on the page is derived from those, so
  # adding a check is one subclass plus a line in `DataHealth::CHECKS`.
  #
  # `scope` must be a relation — the page counts it without loading, and only the
  # first `PREVIEW_LIMIT` rows are rendered.
  class Check
    PREVIEW_LIMIT = 25

    def self.key = name.demodulize.underscore

    def key = self.class.key

    def count
      @count ||= scope.count
    end

    def any? = count.positive?

    def preview
      @preview ||= scope.limit(PREVIEW_LIMIT).to_a
    end

    def more_than_preview = count - preview.size

    # Checks that can only report are the honest default: a wrong row is not
    # always a row we know how to put right (see OrphanedProvenance).
    def repairable? = false

    def repair!
      raise NotImplementedError, "#{self.class.name} reports only"
    end

    def scope
      raise NotImplementedError
    end

    def title
      raise NotImplementedError
    end

    def explanation
      raise NotImplementedError
    end

    # What the fix button says, and what the flash reports afterwards.
    def repair_label = "Fix"

    def repaired_message(number)
      "Fixed #{number} #{'record'.pluralize(number)}."
    end

    def describe(record)
      record.to_s
    end

    # A check whose rows are worth comparing side by side names its column
    # headings here and a partial to render each row; the page falls back to the
    # one-line #describe when both are nil.
    def columns = nil

    def row_partial = nil
  end
end
