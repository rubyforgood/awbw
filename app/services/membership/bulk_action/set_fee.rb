class Membership::BulkAction::SetFee < Membership::BulkAction
  def key = "set_fee"
  def label = "Set membership fee"
  def unit = "membership"
  def param_name = "membership_ids"

  def preview_rows(directory, **)
    directory.scope.includes(person: :user).order(start_date: :desc).map do |membership|
      locked = membership.locked?

      Row.new(
        id: membership.id,
        name: membership.person.full_name,
        email: membership.person.preferred_email,
        detail: current_price_label(membership),
        flags: locked ? [ "Locked" ] : [],
        actionable: !locked
      )
    end
  end

  def perform(directory, ids:, cost_cents: nil, **)
    changed = skipped = failed = 0

    directory.scope.where(id: ids).find_each do |membership|
      if membership.locked? || membership.cost_cents == cost_cents
        skipped += 1
        next
      end

      begin
        membership.update!(cost_cents: cost_cents)
        changed += 1
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
        failed += 1
      end
    end

    Result.new(changed:, skipped:, failed:)
  end

  def notice(result)
    parts = [ "Updated the fee on #{pluralized(result.changed, 'membership')}." ]
    parts << "#{result.skipped} skipped (locked or already at that price)." if result.skipped.positive?
    parts << "#{result.failed} failed." if result.failed.positive?
    parts.join(" ")
  end

  private

  def current_price_label(membership)
    return "Standard (#{MoneyFormatter.dollars_from_cents(Membership.annual_cost_cents)})" if membership.cost_cents.nil?

    MoneyFormatter.dollars_from_cents(membership.cost_cents)
  end
end
