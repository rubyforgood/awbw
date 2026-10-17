module DataHealth
  # Base for one data-consistency check on the admin Data health page.
  #
  # A check answers three things: which rows are wrong (`scope`), how to say that
  # in a sentence (`title` / `explanation`), and whether it can put them right
  # (`repairable?` / `repair!`). Everything on the page is derived from those, so
  # adding a check is one subclass plus a line in `DataHealth::CHECKS`.
  #
  # `scope` must be a relation — the page counts it without loading, and lists
  # its rows `PER_PAGE` at a time.
  class Check
    include Rails.application.routes.url_helpers

    PER_PAGE = 10

    def self.key = name.demodulize.underscore

    def key = self.class.key

    def count
      @count ||= scope.count
    end

    def any? = count.positive?

    def page(number)
      ordered_scope.paginate(page: number, per_page: PER_PAGE, total_entries: count)
    end

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

    # Where each listed row opens, so it can be fixed by hand; nil leaves it plain text.
    def path_for(_record) = nil

    # An existing page that works through these rows, linked from the card header.
    def review_path = nil

    def review_label = "Review"

    private

    # Pages need a stable order; a scope without one is ordered by primary key.
    def ordered_scope
      relation = scope
      return relation if relation.order_values.any?

      relation.order(relation.arel_table[relation.primary_key])
    end
  end
end
