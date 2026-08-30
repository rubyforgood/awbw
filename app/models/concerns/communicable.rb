# A record that carries hand-logged communications alongside its comments, so it
# can render the shared comments-and-communications section.
#
# Including models must define `communications_email` — the address a
# communication logged here is addressed to (usually the record's person). Most
# also want the default `communications_scope`: only what was filed against this
# record. Person overrides it to show a whole history matched by email.
module Communicable
  extend ActiveSupport::Concern

  included do
    has_many :notifications, as: :noticeable, dependent: :nullify
    # A blank subject means the row was added and left untouched, so drop it.
    accepts_nested_attributes_for :notifications, allow_destroy: true, reject_if: proc { |attrs| attrs["email_subject"].blank? }
    before_validation :stamp_new_notification_recipients
  end

  # Communications this record's section shows, newest-first ordering applied by
  # the caller.
  def communications_scope
    notifications
  end

  private

  # A hand-logged communication is addressed to whoever this record is about, so
  # the inline form never asks for a recipient — we stamp it on the way in.
  # Reads the association's in-memory target rather than the association itself,
  # so an unrelated save doesn't load every notification just to find none new.
  def stamp_new_notification_recipients
    pending = association(:notifications).target.select(&:new_record?)
    return if pending.empty?

    email = communications_email.presence || "n/a"
    pending.each { |notification| notification.recipient_email = email }
  end
end
