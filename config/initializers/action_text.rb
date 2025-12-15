default_allowed_tags = Class.new.include(ActionText::ContentHelper).new.sanitizer_allowed_tags
ActionText::ContentHelper.allowed_tags = default_allowed_tags.add("iframe")
