module Analytics
  # One record's own Ahoy history, newest first: what changed, when, and who did
  # it. Reads the (resource_type, resource_id, time) index, so it is cheap enough
  # to render inline on an edit page.
  #
  # Takes every event filed against the record rather than just create/update, so
  # a custom tracked event (`autochange.*` and the like) shows up here too — the
  # action is the part of the event name before the dot.
  class ResourceHistory
    DEFAULT_LIMIT = 25

    Change = Data.define(:label, :before, :after)

    Entry = Data.define(:action, :time, :user, :source, :changes, :association_summary) do
      def detailed? = changes.any? || association_summary.present?
    end

    def initialize(record, limit: DEFAULT_LIMIT)
      @record = record
      @limit = limit
    end

    def entries
      @entries ||= events.map { |event| entry_for(event) }
    end

    def any? = entries.any?

    private

    def events
      return Ahoy::Event.none unless @record&.persisted?

      Ahoy::Event
        .where(resource_type: @record.class.name, resource_id: @record.id)
        .includes(user: :person)
        .order(time: :desc)
        .limit(@limit)
    end


    def entry_for(event)
      properties = event.properties || {}

      Entry.new(
        action: event.name.to_s.split(".").first,
        time: event.time,
        user: event.user,
        source: properties["source"].presence,
        changes: changes_for(properties["changes"]),
        association_summary: association_summary_for(properties["association_changes"])
      )
    end

    def changes_for(raw)
      return [] unless raw.is_a?(Hash)

      raw.filter_map do |attribute, values|
        next unless values.is_a?(Hash)

        Change.new(label: label_for(attribute),
                   before: format_value(values["before"]),
                   after: format_value(values["after"]))
      end
    end

    # e.g. "2 comments added, 1 updated" — enough to know something happened
    # alongside the record's own columns without rebuilding the nested diff.
    def association_summary_for(raw)
      return nil unless raw.is_a?(Hash)

      parts = raw.flat_map do |association, entries|
        next [] unless entries.is_a?(Array)

        entries.group_by { |entry| entry["action"] }.map do |action, group|
          "#{group.size} #{association.to_s.humanize(capitalize: false).singularize.pluralize(group.size)} #{action}"
        end
      end

      parts.presence&.to_sentence
    end

    def label_for(attribute)
      @record.class.human_attribute_name(attribute)
    end

    def format_value(value)
      return "—" if value.nil? || value == ""
      return "Yes" if value == true
      return "No" if value == false

      as_date(value)&.strftime("%b %-d, %Y") || value.to_s
    end

    def as_date(value)
      return nil unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}/)

      Date.parse(value)
    rescue Date::Error
      nil
    end
  end
end
