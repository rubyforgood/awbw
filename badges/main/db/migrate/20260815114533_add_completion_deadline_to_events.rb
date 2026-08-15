class AddCompletionDeadlineToEvents < ActiveRecord::Migration[8.1]
  def up
    return if column_exists?(:events, :completion_deadline)

    # The date a registrant must finish the training by. Date-only (like
    # ce_hours_request_deadline) — "complete by August 30" needs no time of day.
    # Not on-demand-specific: a live event with post-work can carry one too.
    add_column :events, :completion_deadline, :date
  end

  def down
    remove_column :events, :completion_deadline, if_exists: true
  end
end
