class ApplicationJob < ActiveJob::Base
  # Solid Queue stores jobs in a separate queue database, so a job enqueued
  # inside a DB transaction can be claimed and run before that transaction
  # commits — the worker then can't see the not-yet-committed record. Deferring
  # the enqueue until the transaction commits closes that race.
  self.enqueue_after_transaction_commit = true
end
