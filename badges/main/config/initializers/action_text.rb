default_allowed_tags = Class.new.include(ActionText::ContentHelper).new.sanitizer_allowed_tags
ActionText::ContentHelper.allowed_tags = default_allowed_tags.merge(%w[iframe table colgroup col thead tbody tfoot tr th td])

default_allowed_attributes = Class.new.include(ActionText::ContentHelper).new.sanitizer_allowed_attributes
ActionText::ContentHelper.allowed_attributes = default_allowed_attributes.merge(%w[style colspan rowspan cellpadding cellspacing width height align valign])
