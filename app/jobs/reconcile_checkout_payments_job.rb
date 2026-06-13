class ReconcileCheckoutPaymentsJob < ApplicationJob
  queue_as :default

  def perform
    EventRegistration
      .where.not(checkout_session_id: [nil, "unresolved"])
      .where(created_at: ..3.days.ago)
      .find_each do |registration|
        registration.update!(checkout_session_id: "unresolved")
      end
  end
end
