module DataHealth
  # Every check on the admin Data health page, under the heading it renders in, in
  # order. Adding one is a Check subclass plus a line here.
  GROUPS = {
    "Settings" => [
      UnconfiguredAppSettings
    ],
    "Affiliations" => [
      FacilitatorAffiliationsFromNonTrainings,
      MisalignedAffiliationProvenance,
      LegacyOrganizationStatusDrift
    ],
    "People" => [
      PeopleWithSeveralLogins,
      PeopleWithSeveralPrimaries
    ],
    "Registrations" => [
      PeopleRegisteredTwiceForAnEvent
    ],
    "Form answers" => [
      PendingOtherResponses
    ],
    "Payments" => [
      OverAllocatedRegistrations
    ],
    "Stories" => [
      StoriesWithoutWorkshop
    ],
    "Resources" => [
      UnresolvedResourceAgencies
    ],
    "Communications" => [
      UnansweredContactMessages,
      StuckNotifications
    ]
  }.freeze

  CHECKS = GROUPS.values.flatten.freeze

  def self.checks = CHECKS.map(&:new)

  def self.grouped_checks = GROUPS.transform_values { |klasses| klasses.map(&:new) }

  def self.find(key)
    klass = CHECKS.find { |check| check.key == key.to_s }
    klass&.new
  end
end
