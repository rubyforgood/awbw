# frozen_string_literal: true

namespace :data do
  desc "Backfill notifications' created_by_id/updated_by_id from sender_id (nil-only)"
  task backfill_notification_stamps: :environment do
    # A notification's creator/editor is its sender (see Notification#match_stamps_to_sender,
    # which sets this at create going forward). Fill legacy rows from sender_id without
    # overwriting any stamp already set. Idempotent.
    filled = 0
    scope = Notification.where.not(sender_id: nil)
                        .where("created_by_id IS NULL OR updated_by_id IS NULL")

    scope.find_each do |notification|
      notification.update_columns(
        created_by_id: notification.created_by_id || notification.sender_id,
        updated_by_id: notification.updated_by_id || notification.sender_id
      )
      filled += 1
    end

    puts "Notification: backfilled #{filled} #{"row".pluralize(filled)} from sender"
  end
end
