module OrganizationServices
  # The org profile's workshop logs, grouped by workshop like the person profile's,
  # without loading every log: totals are summed in the database, and only the
  # current page of workshop groups loads its logs.
  class WorkshopLogSummary
    GROUPS_PER_PAGE = 9

    # A log groups by its workshop, or by the free-text title when it logged a
    # workshop outside the catalog — the in-memory `workshop_id || external_workshop_title`.
    GROUP_KEY = "COALESCE(CONCAT('w', workshop_logs.workshop_id), CONCAT('x', workshop_logs.external_workshop_title))".freeze

    def initialize(organization)
      @logs = organization.affiliated_workshop_logs
    end

    # { logs:, adults:, teens:, children:, workshops: } across every log.
    def totals
      @totals ||= begin
        logs, adults, teens, children, workshops = @logs.except(:distinct).pick(
          Arel.sql("COUNT(*)"),
          Arel.sql(sum_of(:adults_first_time, :adults_ongoing)),
          Arel.sql(sum_of(:teens_first_time, :teens_ongoing)),
          Arel.sql(sum_of(:children_first_time, :children_ongoing)),
          Arel.sql("COUNT(DISTINCT #{GROUP_KEY})")
        )
        { logs: logs.to_i, adults: adults.to_i, teens: teens.to_i, children: children.to_i, workshops: workshops.to_i }
      end
    end

    # One page of groups — arrays of logs, newest first — ordered by each group's
    # latest log, as a paginatable collection.
    def groups(page:)
      page = [ page.to_i, 1 ].max
      keys = @logs.except(:distinct)
                  .group(Arel.sql(GROUP_KEY))
                  .order(Arel.sql("MAX(COALESCE(workshop_logs.workshop_held_on, DATE(workshop_logs.created_at))) DESC, #{GROUP_KEY}"))
                  .limit(GROUPS_PER_PAGE).offset((page - 1) * GROUPS_PER_PAGE)
                  .pluck(Arel.sql(GROUP_KEY))

      WillPaginate::Collection.create(page, GROUPS_PER_PAGE, totals[:workshops]) do |pager|
        pager.replace(logs_grouped_by(keys))
      end
    end

    private

    def sum_of(*columns)
      "COALESCE(SUM(#{columns.map { |column| "COALESCE(workshop_logs.#{column}, 0)" }.join(" + ")}), 0)"
    end

    # A nil key is the group of logs with neither a workshop nor a title.
    def logs_grouped_by(keys)
      workshop_ids = keys.filter_map { |key| key.delete_prefix("w").to_i if key&.start_with?("w") }
      titles = keys.filter_map { |key| key.delete_prefix("x") if key&.start_with?("x") }
      titles << nil if keys.include?(nil)
      logs = @logs.where(workshop_id: workshop_ids)
                  .or(@logs.where(workshop_id: nil, external_workshop_title: titles))
                  .includes(:workshop, :windows_type, :quotable_item_quotes, :gallery_assets)
                  .order(workshop_held_on: :desc, created_at: :desc)
                  .group_by { |log| group_key(log) }
      keys.filter_map { |key| logs[key] }
    end

    def group_key(log)
      return "w#{log.workshop_id}" if log.workshop_id
      "x#{log.external_workshop_title}" unless log.external_workshop_title.nil?
    end
  end
end
