module MentionableFiltering
  extend ActiveSupport::Concern

  private

  def filter_authorized_mentions(grouped)
    grouped.transform_values do |records|
      next [] if records.empty?

      model_class = records.first.class.name.constantize
      authorized_scope(model_class.where(id: records.map(&:id))).to_a.select(&:persisted?)
    end.compact.reject { |_type, records| records.empty? }
  end
end
