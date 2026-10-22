# The "no address on file" stand-in for two people who share a name and neither
# holds an email — numbered so each of them gets their own. One domain drives the
# address, the Ruby match, the SQL the scope filters on, and the duplicate checks
# that skip seeded addresses.
module PlaceholderEmail
  def self.domain = Setting.placeholder_email_domain

  def self.at(number) = "#{number}@#{domain}"

  def self.first = at(1)

  def self.pattern = /\A(\d+)@#{Regexp.escape(domain)}\z/

  # The same match for MySQL, which the scope filters on in the database.
  def self.sql_pattern = "^[0-9]+@#{Regexp.escape(domain)}$"

  def self.match?(address) = address.to_s.match?(pattern)

  def self.number_in(address) = address.to_s[pattern, 1]&.to_i

  # Any address on the domain, numbered or not: seeded data, which the duplicate
  # checks leave out of their lookups.
  def self.domain_address?(address) = address.to_s.downcase.end_with?("@#{domain}")
end
