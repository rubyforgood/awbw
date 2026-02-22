class BulkInviteService
  attr_reader :ids, :dry_run, :results

  # BulkInviteService.call(ids: [1, 2, 3])
  # BulkInviteService.call(ids: [1, 2, 3], dry_run: true)
  def self.call(ids:, dry_run: false)
    new(ids: ids, dry_run: dry_run).call
  end

  def initialize(ids:, dry_run: false)
    @ids = Array(ids).map(&:to_i)
    @dry_run = dry_run
    @results = { sent: [], failed: [], missing_ids: [] }
  end

  def call
    users = User.where(id: ids)
    @results[:missing_ids] = ids - users.pluck(:id)

    log "Warning: IDs not found: #{results[:missing_ids].join(", ")}" if results[:missing_ids].any?

    if users.none?
      log "No users found."
      return results
    end

    log "Found #{users.count} users:"
    users.find_each { |u| log "  #{u.id}: #{u.name} <#{u.email}>" }

    if dry_run
      log "DRY RUN — no invitations sent."
      return results
    end

    total = users.count
    users.find_each.with_index(1) do |user, index|
      invite_user(user, index, total)
    end

    log "Done. Sent: #{results[:sent].size}, Failed: #{results[:failed].size}"
    results[:failed].each { |e| log "  FAILED: #{e[:email]} — #{e[:error]}" }

    results
  end

  private

  def invite_user(user, index, total)
    User.transaction do
      user.set_welcome_instructions_token!
      user.update!(welcome_instructions_sent_at: Time.current, created_at: nil)
    end

    BulkInviteEmailJob.perform_later(user.id)
    results[:sent] << { id: user.id, email: user.email }
    log "  Invited #{user.email} (#{index}/#{total})"
  rescue => e
    results[:failed] << { id: user.id, email: user.email, error: e.message }
    log "  FAILED #{user.email}: #{e.message} (#{index}/#{total})"
  end

  def log(message)
    puts message
  end
end
