module InlineActivityHelper
  def inline_record_path(record, fallback: root_path)
    return fallback if record.blank?

    polymorphic_path(inline_record(record))
  rescue ActionController::UrlGenerationError, NoMethodError
    fallback
  end

  private

  def inline_record(record)
    model = record.respond_to?(:to_model) ? record.to_model : record
    model.becomes(model.class.base_class)
  end
end
