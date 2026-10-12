module UserServices
  # Logins that share one person — typically left behind when a person merge keeps
  # both people's logins. The most recently updated login (the one the person signs
  # in with) leads each group so the deduper suggests keeping it.
  class DuplicateFinder
    Group = Struct.new(:key, :label, :records, :reasons, keyword_init: true)

    def initialize(scope = User.all)
      @scope = scope
    end

    def groups
      shared_person_ids = @scope.where.not(person_id: nil).group(:person_id).having("COUNT(*) > 1").select(:person_id)
      @scope.where(person_id: shared_person_ids).includes(:person)
        .order(updated_at: :desc, id: :desc)
        .group_by(&:person_id)
        .map do |person_id, records|
          Group.new(key: person_id.to_s, label: records.first.person.full_name.to_s, records: records, reasons: [ "Same person" ])
        end
        .sort_by { |group| group.label.downcase }
    end
  end
end
