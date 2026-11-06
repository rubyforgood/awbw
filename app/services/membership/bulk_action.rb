class Membership::BulkAction
  Row = Data.define(:id, :name, :email, :detail, :flags, :actionable)

  Result = Data.define(:changed, :skipped, :failed_ids, :errors)

  ACTIONS = [
    Membership::BulkAction::SetFee,
    Membership::BulkAction::LockAccount
  ].freeze

  def self.all = ACTIONS.map(&:new)

  def self.for(key) = all.find { |action| action.key == key.to_s }

  # Each action requires the following:
  # key
  # label
  # unit
  # param_name
  # preview_rows(directory, ids: nil)
  # perform(directory, ids:, ...)
  # notice(result)

  private

  def pluralized(count, noun) = "#{count} #{noun.pluralize(count)}"

  def error_message(record, error)
    messages = record.errors.full_messages
    messages = [ error.message ] if messages.empty?
    messages.to_sentence
  end
end
