require "csv"

# Records StaffAlias rows from a staff list: one row per FileMaker staff name, with the
# portal user it means. The list pairs real names with real accounts, so it's read from a
# file at run time rather than kept in the repo.
#
# Columns (CSV or tab-separated, matched case-insensitively):
#   staff              the name as FileMaker recorded it (required)
#   user_ids_by_email  the portal user's id
#   portal_user_email  the portal user's email, tried when there's no id
#   ignored            true/yes/1 for a name that means no one (a shared "Staff" login)
#
# Idempotent: a name already recorded is left alone, so an alias corrected by hand
# survives a re-run. A name no user answers to yet is reported, not recorded, so running
# it again once that account exists picks it up.
class StaffAliasLoader
  TRUTHY = %w[true yes y 1 x].freeze

  attr_reader :created, :kept, :unresolved

  def self.call(...)
    new(...).call
  end

  def initialize(path, quiet: false)
    @path = path
    @quiet = quiet
    @created = 0
    @kept = 0
    @unresolved = []
  end

  def call
    rows.each { |row| record(row) }
    report
    self
  end

  private

  def rows
    content = File.read(@path, encoding: "bom|utf-8")
    col_sep = content.lines.first.to_s.include?("\t") ? "\t" : ","
    CSV.parse(content, headers: true, col_sep:, header_converters: ->(header) { header.to_s.strip.downcase })
  end

  def record(row)
    name = row["staff"].to_s.squish
    return if name.empty?
    return @kept += 1 if StaffAlias.exists?(name:)

    ignored = TRUTHY.include?(row["ignored"].to_s.strip.downcase)
    user = user_for(row) unless ignored
    return @unresolved << name unless ignored || user

    StaffAlias.create!(name:, user:, ignored:)
    @created += 1
  end

  def user_for(row)
    id = row["user_ids_by_email"].to_s[/\d+/]
    email = row["portal_user_email"].to_s.strip.downcase.presence
    (id && User.find_by(id:)) || (email && User.find_by(email:))
  end

  def report
    return if @quiet

    puts "  #{@created} staff aliases added, #{@kept} already recorded (#{StaffAlias.count} total)"
    puts "  #{@unresolved.size} names with no portal user: #{@unresolved.join(', ')}" if @unresolved.any?
  end
end
