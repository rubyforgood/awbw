# Preloads what a comment/communication record label reads — the person a feed
# chip names (with their account, for the hover email) and the event in the
# label — so a page of entries, or a person's picker targets, costs a fixed
# number of queries. Takes comments, communications, or the records themselves.
class FeedRecordPreloader
  REGISTRATION = [ :event, { registrant: :user } ].freeze
  ASSOCIATIONS = {
    Person => :user,
    EventRegistration => REGISTRATION,
    ContinuingEducationRegistration => { event_registration: REGISTRATION },
    Scholarship => [ { recipient: :user }, { allocation: :allocatable } ]
  }.freeze

  def initialize(entries)
    @entries = entries.to_a
  end

  def call
    records = @entries.filter_map { |entry| attached_record(entry) }
    preload(records)
    preload(records.grep(Scholarship).filter_map { |scholarship| scholarship.allocation&.allocatable })
    @entries
  end

  private

  def attached_record(entry)
    case entry
    when Comment then entry.commentable
    when Notification then entry.noticeable
    else entry
    end
  end

  def preload(records)
    records.group_by(&:class).each do |klass, group|
      associations = ASSOCIATIONS[klass]
      next unless associations

      ActiveRecord::Associations::Preloader.new(records: group, associations: associations).call
    end
  end
end
