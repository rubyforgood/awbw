namespace :users do
  # bin/rails users:bulk_invite IDS=1,2,3
  # bin/rails users:bulk_invite IDS=1,2,3 DRY_RUN=true
  desc "Bulk send welcome instructions to specified users"
  task bulk_invite: :environment do
    unless ENV["IDS"].present?
      puts "Usage: bin/rails users:bulk_invite IDS=1,2,3 [DRY_RUN=true]"
      next
    end

    ids = ENV["IDS"].split(",").map(&:strip)
    users = User.where(id: ids)
    total = users.count

    missing = ids.map(&:to_i) - users.pluck(:id)
    puts "Warning: IDs not found: #{missing.join(", ")}" if missing.any?

    if total == 0
      puts "No uninvited, unconfirmed users found."
      next
    end

    puts "Found #{total} uninvited, unconfirmed users:"
    users.find_each { |u| puts "  #{u.id}: #{u.name} <#{u.email}>" }
    puts ""

    if ENV["DRY_RUN"] == "true"
      puts "DRY_RUN=true — no invitations sent."
      next
    end

    print "Send welcome instructions to all #{total} users? (yes/no): "
    confirm = $stdin.gets&.strip
    unless confirm == "yes"
      puts "Aborted."
      next
    end

    sent = 0
    errors = []

    users.find_each do |user|
      user.set_welcome_instructions_token!
      user.update!(welcome_instructions_sent_at: Time.current)
      user.send_confirmation_instructions
      sent += 1
      puts "  Invited #{user.email} (#{sent}/#{total})"
    rescue => e
      errors << { id: user.id, email: user.email, error: e.message }
      puts "  FAILED #{user.email}: #{e.message}"
    end

    puts ""
    puts "Done. Sent: #{sent}, Failed: #{errors.size}"
    errors.each { |e| puts "  FAILED: #{e[:email]} — #{e[:error]}" } if errors.any?
  end
end
