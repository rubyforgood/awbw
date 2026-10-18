class FormFieldDecorator < ApplicationDecorator
  # Persisted rows keep their stable id; a new question only needs an anchor when
  # the error summary links to it, keyed by its place in the editor list.
  def anchor_id(index)
    persisted? ? "form_field_#{id}" : "new_form_field_#{index}"
  end

  def error_label(number)
    title = name.presence ? "“#{h.truncate(name, length: 60)}”" : "(untitled)"
    "Question #{number} #{title}"
  end

  # The question's own errors plus its answer options', in plain words. Nested
  # option errors are rebuilt per option so each one quotes the offending text.
  def error_messages
    own = errors.reject { |error| error.attribute.to_s.include?(".") }.map(&:full_message)
    option_errors = form_field_answer_options.flat_map do |option|
      option.errors.map { |error| "Answer option “#{h.truncate(option.option_name.to_s, length: 40)}” #{error.message}" }
    end
    own + option_errors
  end

  def answer_option_errors?
    form_field_answer_options.any? { |option| option.errors.any? }
  end
end
