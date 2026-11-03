class Membership::BulkAction::Registry
  ACTIONS = [
    Membership::BulkAction::SetFee,
    Membership::BulkAction::LockAccount
  ].freeze

  def self.all = ACTIONS.map(&:new)

  def self.for(key) = all.find { |action| action.key == key.to_s }
end
