# Finds the existing Person a name belongs to when there's no email to go on (a
# spreadsheet row without one). A same-named person affiliated with the given
# organization wins; otherwise the name alone matches only when exactly one person
# carries it. The first name may be the stored first or legal first name. Two or
# more candidates match no one — `candidate_count` says how many were in the way.
class PersonNameMatcher
  Result = Data.define(:person, :basis, :candidate_count)

  def self.call(...)
    new(...).call
  end

  def initialize(first_name:, last_name:, organization: nil)
    @first_name = Person.normalize_name(first_name).to_s.downcase
    @last_name = Person.normalize_name(last_name).to_s.downcase
    @organization = organization
  end

  def call
    return Result.new(person: nil, basis: nil, candidate_count: 0) if @first_name.blank? || @last_name.blank?

    if @organization
      at_organization = candidates.where(id: Affiliation.where(organization: @organization).select(:person_id))
      return Result.new(person: at_organization.first, basis: :name_and_organization, candidate_count: 1) if at_organization.count == 1
    end

    count = candidates.count
    return Result.new(person: candidates.first, basis: :name, candidate_count: 1) if count == 1

    Result.new(person: nil, basis: nil, candidate_count: count)
  end

  private

  def candidates
    Person.where("LOWER(people.last_name) = ?", @last_name)
      .where("LOWER(people.first_name) = :name OR LOWER(COALESCE(people.legal_first_name, '')) = :name", name: @first_name)
  end
end
