module DataHealth
  # Every check on the admin Data health page, in the order it renders. Adding one
  # is a Check subclass plus a line here.
  CHECKS = [
    FacilitatorAffiliationsFromNonTrainings,
    MisalignedAffiliationProvenance,
    LegacyOrganizationStatusDrift
  ].freeze

  def self.checks = CHECKS.map(&:new)

  def self.find(key)
    klass = CHECKS.find { |check| check.key == key.to_s }
    klass&.new
  end
end
