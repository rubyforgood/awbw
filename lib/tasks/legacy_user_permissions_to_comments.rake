namespace :legacy do
  desc "Convert legacy user_permissions rows into User comments"
  task user_permissions_to_comments: :environment do
    say = ->(msg) { puts "[legacy:user_permissions_to_comments] #{msg}" }

    connection = ActiveRecord::Base.connection

    rows = connection.exec_query(<<~SQL)
      SELECT up.user_id, p.security_cat AS permission_name
      FROM user_permissions up
      INNER JOIN permissions p ON p.id = up.permission_id
    SQL

    say.call "Found #{rows.rows.size} legacy user_permissions rows to process"

    processed = 0
    skipped   = 0

    rows.each do |row|
      user_id         = row["user_id"]
      permission_name = row["permission_name"]

      user = User.find_by(id: user_id)
      unless user
        skipped += 1
        next
      end

      body = "Legacy data note: user had permission to #{permission_name}. " \
             "Deleted legacy permission tracking for all users on 2026-03-05."

      # Avoid creating duplicate comments if the task is re-run
      unless user.comments.where(body: body).exists?
        user.comments.create!(body: body)
        processed += 1
      else
        skipped += 1
      end
    end

    say.call "Created #{processed} comments on users (skipped #{skipped})."
  end
end
