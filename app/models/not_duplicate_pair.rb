# Two records an admin reviewed on a dedupe page and confirmed are different, so
# the possible-duplicates list stops pairing them. Ids are stored lowest first.
class NotDuplicatePair < ApplicationRecord
  Marked = Data.define(:pair, :records)

  belongs_to :created_by, class_name: "User", optional: true

  validates :record_type, :first_record_id, :second_record_id, presence: true
  validates :second_record_id, uniqueness: { scope: %i[record_type first_record_id] }
  validates :second_record_id, comparison: { greater_than: :first_record_id }

  scope :for_model, ->(model_class) { where(record_type: model_class.polymorphic_name) }
  scope :involving, ->(record) {
    for_model(record.class).where(first_record_id: record.id).or(for_model(record.class).where(second_record_id: record.id))
  }

  def self.mark!(records)
    record_type = records.first.class.polymorphic_name
    transaction do
      records.map(&:id).uniq.combination(2).each { |ids| pair!(record_type, ids) }
    end
  end

  # A merged-away record was the same as the keeper, so whatever it wasn't a duplicate of, neither is the keeper.
  def self.transfer!(from:, to:)
    record_type = to.class.polymorphic_name
    involving(from).find_each do |pair|
      other_id = pair.first_record_id == from.id ? pair.second_record_id : pair.first_record_id
      pair!(record_type, [ other_id, to.id ]) unless other_id == to.id
    end
    involving(from).delete_all
  end

  def self.pair!(record_type, ids)
    first_id, second_id = ids.minmax
    find_or_create_by!(record_type: record_type, first_record_id: first_id, second_record_id: second_id)
  end
  private_class_method :pair!

  def self.marked(model_class)
    pairs = for_model(model_class).includes(:created_by).order(created_at: :desc).to_a
    ids = pairs.flat_map { |pair| [ pair.first_record_id, pair.second_record_id ] }
    by_id = model_class.where(id: ids).index_by(&:id)
    pairs.filter_map do |pair|
      records = by_id.values_at(pair.first_record_id, pair.second_record_id)
      Marked.new(pair: pair, records: records) if records.all?
    end
  end

  def self.id_pairs_for(model_class)
    for_model(model_class).pluck(:first_record_id, :second_record_id).to_set
  end
end
