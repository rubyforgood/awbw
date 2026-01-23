class ActionTextMention < ApplicationRecord
  belongs_to :action_text_rich_text, class_name: "ActionText::RichText"
  belongs_to :mentionable, polymorphic: true
end
