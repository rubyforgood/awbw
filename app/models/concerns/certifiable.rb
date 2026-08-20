module Certifiable
  extend ActiveSupport::Concern

  # Includers define their own `certificate_available?` — the eligibility rules differ.

  # Sending the certificate email is how it's issued, so certificate_sent_at
  # doubles as the "issued" marker.
  def certificate_sent?
    certificate_sent_at.present?
  end

  def mark_certificate_sent!(at: Time.current)
    update!(certificate_sent_at: at)
  end
end
