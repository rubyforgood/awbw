class Membership::BulkAction::EmailMembers < Membership::BulkAction
  def key = "email_members"
  def label = "Email members"
  def unit = "membership"
  def param_name = "membership_ids"
  def submit_label = "Send emails"

  def preview_rows(directory, ids: nil, **)
    scope = directory.scope.includes(person: :user).order(start_date: :desc)
    scope = scope.where(id: ids) if ids

    scope.map do |membership|
      person = membership.person
      user = person.user

      Row.new(
        id: membership.id,
        name: person.full_name,
        email: user&.email.presence || person.preferred_email,
        detail: nil,
        flags: flags_for(membership, user),
        actionable: user.present? && user.has_access? && !membership.locked? && membership.cost_cents != 0
      )
    end
  end

  def perform(directory, ids:, custom_subject: nil, custom_message: nil, **)
    changed = skipped = 0
    errors = []
    failed_ids = []

    directory.scope.where(id: ids).includes(person: :user).find_each do |membership|
      person = membership.person
      user = person.user

      if membership.locked? || membership.cost_cents == 0 || user.nil? || !user.has_access? || user.email.blank?
        skipped += 1
        next
      end

      begin
        NotificationServices::CreateNotification.call(
          noticeable: membership,
          person:,
          kind: :membership_invoice,
          recipient_role: :person,
          recipient_email: user.email,
          notification_type: 0,
          sender: Current.user,
          bulk: true,
          custom_subject: custom_subject.presence,
          custom_message: custom_message.presence
        )
        changed += 1
      rescue StandardError => e
        failed_ids << membership.id
        errors << "#{person.full_name}: #{error_message(membership, e)}"
      end
    end

    Result.new(changed:, skipped:, failed_ids:, errors:)
  end

  def notice(result)
    parts = [ "Queued #{pluralized(result.changed, 'membership email')}." ]
    parts << "#{result.skipped} skipped (no portal access, no fee, or locked)." if result.skipped.positive?
    parts << "#{result.failed_ids.size} failed." if result.failed_ids.any?
    parts.join(" ")
  end

  private

  def flags_for(membership, user)
    flags = []
    flags << "No portal access" unless user&.has_access?
    flags << "No fee" if membership.cost_cents == 0
    flags << "Locked" if membership.locked?
    flags
  end
end
