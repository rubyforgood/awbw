default_allowed_tags = Class.new.include(ActionText::ContentHelper).new.sanitizer_allowed_tags
ActionText::ContentHelper.allowed_tags = default_allowed_tags.merge(%w[iframe table colgroup col thead tbody tfoot tr th td])

default_allowed_attributes = Class.new.include(ActionText::ContentHelper).new.sanitizer_allowed_attributes
ActionText::ContentHelper.allowed_attributes = default_allowed_attributes.merge(%w[style colspan rowspan cellpadding cellspacing width height align valign target])

module ActionText
  class TrixAttachment
    # Any @mention model should use this content type so it renders inline in the editor
    INLINE_CONTENT_TYPE_PREFIX = "application/vnd.active_record.".freeze

    alias_method :to_html_original, :to_html

    def to_html
      html = to_html_original
      return html unless inline_attachment?

      # Replace <figure> wrapper with <span>
      html
        .sub(/\A<figure/, "<span")
        .sub(%r{</figure>\z}, "</span>")
    end

    private

    def inline_attachment?
      attributes["contentType"]&.start_with?(INLINE_CONTENT_TYPE_PREFIX)
    end
  end
end
