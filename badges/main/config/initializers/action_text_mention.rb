ActiveSupport.on_load(:action_text_rich_text) do
  ActionText::RichText.class_eval do
    MENTIONABLE_MODELS = [ Workshop, Resource, RichTextAsset ]

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

      (existing_records - current_records).each do |record|
        action_text_mentions.find_by(mentionable: record)&.destroy
      end

      (current_records - existing_records).each do |record|
        action_text_mentions.build(mentionable: record)
      end
    end

    before_save do
      MENTIONABLE_MODELS.each do |klass|
        update_mentions_for(klass)
      end
    end
  end
end
