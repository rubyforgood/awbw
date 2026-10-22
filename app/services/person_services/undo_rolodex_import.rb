module PersonServices
  # Reverses one FileMaker import run (fm:import_people, fm:import_organizations) from the
  # activity events it logged under it (`import_run`). Newest first, so a record's addresses,
  # tags, comments and affiliations go before the record. A record created by the run is deleted, and a field the run filled goes back to
  # its value before the run — unless someone has changed it since, which is kept and reported.
  class UndoRolodexImport
    OUTCOMES = %i[deleted reverted kept gone].freeze

    attr_reader :results

    def initialize(run:)
      @run = run
      @results = OUTCOMES.index_with { [] }
    end

    # Untouched, so deleting a person's address doesn't make the person look edited since.
    def call
      ActiveRecord::Base.no_touching do
        events.each do |event|
          case event.name
          when /\Acreate\./ then undo_create(event)
          when /\Aupdate\./ then undo_update(event)
          end
        end
      end
      Analytics::LifecycleBuffer.flush_to(Ahoy::Tracker.new)
      self
    end

    private

    def events
      Ahoy::Event.where("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.import_run')) = ?", @run).order(id: :desc)
    end

    def undo_create(event)
      record, label = record_for(event)
      return @results[:gone] << label unless record
      return @results[:kept] << "#{label}: changed since the import" if changed_since?(record, event)
      return @results[:deleted] << label if record.destroy

      @results[:kept] << "#{label}: #{record.errors.full_messages.to_sentence}"
    end

    def undo_update(event)
      record, label = record_for(event)
      return @results[:gone] << label unless record

      untouched, changed = event.properties["changes"].to_h.partition { |attribute, change| still?(record, attribute, change["after"]) }
      changed.each { |attribute, _| @results[:kept] << "#{label} #{attribute}: changed since the import" }
      return if untouched.empty?

      untouched.each { |attribute, change| record[attribute] = change["before"] }
      record.save(validate: false)
      @results[:reverted] << "#{label}: #{untouched.map(&:first).join(", ")}"
    end

    def record_for(event)
      type, id = event.properties.values_at("resource_type", "resource_id")
      [ type.to_s.safe_constantize&.find_by(id:), "#{type} ##{id}" ]
    end

    def still?(record, attribute, value)
      record.has_attribute?(attribute) && record[attribute] == record.class.type_for_attribute(attribute).cast(value)
    end

    # The run's own writes all land before its events are logged, so a later edit or touch
    # is the only way a record it created is newer than its event.
    def changed_since?(record, event)
      record.respond_to?(:updated_at) && record.updated_at.present? && record.updated_at > event.time
    end
  end
end
