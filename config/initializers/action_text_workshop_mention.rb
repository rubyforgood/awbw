ActiveSupport.on_load(:action_text_rich_text) do
  ActionText::RichText.class_eval do
    has_many :workshop_mentions, class_name: "ActionTextWorkshopMention", foreign_key: :action_text_rich_text_id, dependent: :destroy
    has_many :workshops, through: :workshop_mentions

    before_save do
      self.workshops = body.attachables.grep(Workshop).uniq if body.present?
    end
  end
end
