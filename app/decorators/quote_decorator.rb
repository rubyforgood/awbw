class QuoteDecorator < ApplicationDecorator
  def title
    "#{attribution} re #{workshop&.title}"
  end

  def detail(length: nil)
    text = object.body
    length ? text&.truncate(length) : text
  end

  def created_by
    object.created_by || object.quotable_item_quotes.last&.quotable&.decorate&.created_by
  end

  def body
    object.body
  end

  def attribution
    name = author&.name.presence || speaker_name.presence || "anonymous"

    details = []
    details << "#{age.gsub("years", "").gsub("yrs", "")} yrs" if age.present?
    details << gender if gender.present?

    if details.any?
      "#{name} (#{details.join(', ')})"
    else
      name
    end
  end
end
