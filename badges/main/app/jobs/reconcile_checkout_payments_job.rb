class ReconcileCheckoutPaymentsJob < ApplicationJob
  queue_as :default

  def perform
    EventRegistration
      .where(payment_unresolved: nil)
      .where.not(checkout_session_id: nil)
      .where(created_at: ..3.days.ago)
      .find_each do |registration|
        registration.update!(payment_unresolved: true)
      end
  end
end
