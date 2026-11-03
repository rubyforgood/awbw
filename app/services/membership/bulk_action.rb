class Membership::BulkAction
  Row = Data.define(:id, :name, :email, :detail, :flags, :actionable) do
    def actionable? = actionable
  end

  Result = Data.define(:changed, :skipped, :failed) do
    def any? = changed.positive? || skipped.positive? || failed.positive?
  end

  def self.for(key) = Registry.for(key)

  def self.all = Registry.all

  def key = raise NotImplementedError
  def label = raise NotImplementedError
  def unit = raise NotImplementedError
  def param_name = raise NotImplementedError

  def preview_rows(directory, **options) = raise NotImplementedError
  def perform(directory, ids:, **options) = raise NotImplementedError
  def notice(result) = raise NotImplementedError

  private

  def dollars(cents) = cents.nil? ? "Standard" : MoneyFormatter.dollars_from_cents(cents)

  def pluralized(count, noun) = "#{count} #{noun.pluralize(count)}"
end
