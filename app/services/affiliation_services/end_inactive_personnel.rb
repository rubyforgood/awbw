module AffiliationServices
  # Round one, pass two of ADR-0011: gives each Facilitator affiliation the Personnel import
  # ended without an end date one, so program status (which reads only dates) stops counting it
  # as running. FileMaker never recorded when they stopped, so the date is the first evidence
  # that fits, else December 31 of the year the row started; a comment names which.
  class EndInactivePersonnel
    include FilemakerValues

    SOURCES = {
      own_log: "their own last workshop log on that project",
      saved: "the day FileMaker last saved the Personnel row",
      project_log: "the project's last workshop log",
      stand_in: "December 31 of the year they started (a stand-in)"
    }.freeze
    OUTCOMES = [ *SOURCES.keys, :skipped, :failed ].freeze
    BATCH_SIZE = 500
    LEFT_NOTE = /\bno longer (with|at|works|employed)\b|\bleft\b/i
    PERSONNEL_CODE = /\APS/i
    COMMENT_TOPIC = ImportPersonnel::COMMENT_TOPIC
    SOURCE = "fm_end_inactive_personnel"

    attr_reader :results

    def initialize(progress: nil)
      @progress = progress
      @results = OUTCOMES.index_with { [] }
    end

    def call
      load_indexes
      read = 0
      Current.set(source: Current.source || SOURCE) do
        scope.find_in_batches(batch_size: BATCH_SIZE) do |affiliations|
          ActiveRecord::Base.transaction(requires_new: true) do
            ActiveRecord::Base.no_touching { affiliations.each { |affiliation| end_affiliation(affiliation) } }
          ensure
            Analytics::LifecycleBuffer.store.clear
          end
          read += affiliations.size
          @progress&.call(read)
        end
      end
      self
    end

    def scope
      Affiliation.facilitators.where(inactive: true, end_date: nil).where("affiliations.filemaker_code LIKE ?", "%PS%")
    end

    private

    def load_indexes
      @personnel = FmPersonnel.all.index_by(&:fm_id)
      @own_logs = {}
      @project_logs = {}
      FmWorkshopLog.pluck(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(data, '$.LeaderID'))"),
                          Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(data, '$.ProjectID'))"),
                          Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(data, '$.WorkshopDate'))")).each do |leader, project, date|
        held_on = parse_date(date)
        next unless held_on && project.present?

        latest(@project_logs, project.strip, held_on)
        latest(@own_logs, [ leader.to_s.strip, project.strip ], held_on) if leader.present?
      end
    end

    def latest(index, key, date)
      index[key] = date if index[key].nil? || date > index[key]
    end

    def end_affiliation(affiliation)
      label = "affiliation ##{affiliation.id} (#{affiliation.filemaker_code})"
      row = personnel_row(affiliation)
      return record(:skipped, "#{label}: no FileMaker Personnel row for its code") unless row
      return record(:skipped, "#{label}: no start date") unless affiliation.start_date

      source, ends_on = end_date_for(row, affiliation.start_date)
      return record(:skipped, "#{label}: started #{affiliation.start_date.iso8601}, too recently for an end date") unless ends_on

      affiliation.end_date = ends_on
      return record(:failed, "#{label}: #{affiliation.errors.full_messages.to_sentence}") unless affiliation.save

      affiliation.comments.create!(topic: COMMENT_TOPIC,
                                   body: "End date set to #{ends_on.iso8601} from #{SOURCES[source]}. " \
                                         "FileMaker recorded that they stopped, but not when.")
      record(source, "#{label} → #{ends_on.iso8601}")
    end

    def personnel_row(affiliation)
      affiliation.filemaker_codes.grep(PERSONNEL_CODE).filter_map { |code| @personnel[code] }.first
    end

    # The first candidate on or after the start and before today. A left note makes the day the
    # row was last saved the best evidence, since that's when staff wrote it down.
    def end_date_for(row, start)
      data = row.data
      project = data["ProjectID"].to_s.strip
      candidates = {
        own_log: @own_logs[[ data["PersonID"].to_s.strip, project ]],
        saved: parse_date(data["DateTimeModified"]),
        project_log: @project_logs[project],
        stand_in: [ start.end_of_year, Date.yesterday ].min
      }
      order = data["Notes"].to_s.match?(LEFT_NOTE) ? %i[saved own_log project_log stand_in] : %i[own_log saved project_log stand_in]
      order.each do |source|
        date = candidates[source]
        return [ source, date ] if date && date >= start && date < Date.current
      end
      nil
    end

    def record(outcome, message)
      @results[outcome] << message
      nil
    end
  end
end
