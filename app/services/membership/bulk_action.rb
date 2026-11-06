class Membership::BulkAction
  Row = Data.define(:id, :name, :email, :detail, :flags, :actionable) do
    def actionable? = actionable
  end

  Result = Data.define(:changed, :skipped, :failed, :errors, :failed_ids)

  ACTIONS = [
    Membership::BulkAction::SetFee,
    Membership::BulkAction::LockAccount
  ].freeze

  def self.all = ACTIONS.map(&:new)

  def self.for(key) = all.find { |action| action.key == key.to_s }

  def key = raise NotImplementedError
  def label = raise NotImplementedError
  def unit = raise NotImplementedError
  def param_name = raise NotImplementedError

  def preview_rows(directory, **options) = raise NotImplementedError
  def perform(directory, ids:, **options) = raise NotImplementedError
  def notice(result) = raise NotImplementedError

  private

  def pluralized(count, noun) = "#{count} #{noun.pluralize(count)}"

  def error_message(record, error)
    messages = record.errors.full_messages
    messages = [ error.message ] if messages.empty?
    messages.to_sentence
  end
end
