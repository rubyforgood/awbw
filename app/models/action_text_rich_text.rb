# Alias model to provide the constant that SearchCop expects
# SearchCop tries to convert action_text_rich_texts -> ActionTextRichText constant
# But the actual ActionText model is namespaced as ActionText::RichText
class ActionTextRichText < ActionText::RichText
  self.table_name = "action_text_rich_texts"
end
