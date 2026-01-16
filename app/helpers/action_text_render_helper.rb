
module ActionTextRenderHelper
  def content_has_value?(content, title: nil)
    return false if content.nil?

    if content.is_a?(ActionText::RichText)
      return false unless content.body
      content.body.to_plain_text.strip.present? || content.body.attachments.any?
    else
      # Workshop time frame
      return false if title == "Suggested time frame" && content.to_s == "00:00"

      content.present?
    end
  end
end
