module InlineActivityHelper
  def inline_field_class
    "w-full bg-white rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-blue-500 focus:ring focus:ring-blue-200 focus:outline-none"
  end

  def inline_select_class
    "w-32 bg-white rounded-md border border-gray-300 px-2 py-1 text-xs shadow-sm focus:border-blue-500 focus:ring focus:ring-blue-200 focus:outline-none"
  end

  def inline_datetime_class
    "w-full bg-white rounded-md border border-gray-300 px-2 py-1 text-xs shadow-sm focus:border-blue-500 focus:ring focus:ring-blue-200 focus:outline-none"
  end

  def inline_datetime_value(time)
    (time || Time.current).strftime("%Y-%m-%dT%H:%M")
  end

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
