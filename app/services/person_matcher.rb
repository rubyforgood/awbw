# Finds the existing Person a submitted name + email belongs to. The email may sit in
# any of the person's addresses (primary, secondary, or their login), since that's what
# the person sees as "their email". Pass first_names to also require a first-name match
# against the stored first or legal first name; omit it to match on email + last name.
class PersonMatcher
  def self.call(...)
    new(...).call
  end

  def initialize(email:, last_name:, first_names: nil)
    @email = email.to_s.strip.downcase
    @last_name = Person.normalize_name(last_name).to_s.downcase
    @first_names = first_names&.filter_map { |name| Person.normalize_name(name)&.downcase.presence }&.uniq
  end

  def call
    return if @email.blank? || @last_name.blank?
    return if @first_names&.empty?

    scope = Person.left_joins(:user)
      .where("LOWER(people.last_name) = ?", @last_name)
      .where("LOWER(people.email) = :email OR LOWER(people.email_2) = :email OR LOWER(users.email) = :email", email: @email)
    scope = scope.where(
      "LOWER(people.first_name) IN (:names) OR LOWER(COALESCE(people.legal_first_name, '')) IN (:names)",
      names: @first_names
    ) if @first_names
    scope.first
  end
end
