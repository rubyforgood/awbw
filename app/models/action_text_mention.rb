class ActionTextMention < ApplicationRecord
  belongs_to :action_text_rich_text, class_name: "ActionText::RichText"
  belongs_to :mentionable, polymorphic: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
end
