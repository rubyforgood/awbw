class FormAnswerDecorator < ApplicationDecorator
  delegate_all

  # Full answer text for a hover tooltip, pretty-printed when it's a JSON
  # object/array so structured answers are readable instead of one long line.
  def tooltip_text
    text = submitted_answer.to_s
    return text unless text.strip.start_with?("{", "[")

    JSON.pretty_generate(JSON.parse(text))
  rescue JSON::ParserError
    text
  end
end
