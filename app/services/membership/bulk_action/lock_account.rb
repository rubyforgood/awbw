class Membership::BulkAction::LockAccount < Membership::BulkAction
  def key = "lock_account"
  def label = "Lock user accounts"
  def unit = "person"
  def param_name = "person_ids"

  def preview_rows(directory, **)
    counts = directory.scope.group(:person_id).count
    people = Person.where(id: counts.keys).includes(:user).order(:first_name, :last_name)

    people.map do |person|
      user = person.user
      locked = user&.locked_at.present?
      flags = []
      flags << pluralized(counts[person.id], "membership") if counts[person.id].to_i > 1
      flags << "No login" if user.nil?
      flags << "Already locked" if locked

      Row.new(
        id: person.id,
        name: person.full_name,
        email: person.preferred_email,
        detail: nil,
        flags: flags,
        actionable: user.present? && !locked
      )
    end
  end

  def perform(directory, ids:, **)
    changed = skipped = failed = 0

    Person.where(id: directory.scope.select(:person_id))
      .where(id: ids)
      .includes(:user)
      .find_each do |person|
        user = person.user
        if user.nil? || user.locked_at.present?
          skipped += 1
          next
        end

        begin
          user.update!(locked_at: Time.current)
          changed += 1
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
          failed += 1
        end
      end

    Result.new(changed:, skipped:, failed:)
  end

  def notice(result)
    parts = [ "Locked #{pluralized(result.changed, 'user account')}." ]
    parts << "#{result.skipped} skipped (no login or already locked)." if result.skipped.positive?
    parts << "#{result.failed} failed." if result.failed.positive?
    parts.join(" ")
  end
end
