# ActiveSupport.on_load(:action_text_rich_text) do
#   ActionText::RichText.class_eval do
#     has_many :workshop_mentions, class_name: "ActionTextWorkshopMention", foreign_key: :action_text_rich_text_id, dependent: :destroy
#     has_many :workshops, through: :workshop_mentions
#
#     before_save do
#       self.workshops = body.attachables.grep(Workshop).uniq if body.present?
#     end
#   end
# end


ActiveSupport.on_load(:action_text_rich_text) do
  ActionText::RichText.class_eval do
    has_many :action_text_mentions,
             class_name: "ActionTextMention",
             foreign_key: :action_text_rich_text_id,
             dependent: :destroy

    def mentions_for(klass)
      action_text_mentions.where(mentionable_type: klass.name).map(&:mentionable)
    end

    def all_mentions
      action_text_mentions.includes(:mentionable).map(&:mentionable)
    end

    def update_mentions_for(klass)
      return unless body.present?

      current_records = body.attachables.grep(klass).uniq
      existing_records = action_text_mentions
                           .where(mentionable_type: klass.name)
                           .map(&:mentionable)

      # Remove mentions no longer in body
      (existing_records - current_records).each do |record|
        action_text_mentions.find_by(mentionable: record)&.destroy
      end

      # Add new mentions
      (current_records - existing_records).each do |record|
        action_text_mentions.build(mentionable: record)
      end
    end

    before_save do
      ActionText::MentionableRegistry.registered_models.each do |klass|
        update_mentions_for(klass)
      end
    end
  end
end
