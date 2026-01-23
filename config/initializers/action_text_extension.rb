Rails.application.config.to_prepare do
  ActionText::RichText.class_eval do
    before_save :update_plain_text_body

    def update_plain_text_body
      self.plain_text_body = body.to_plain_text if body.present?
    end
  end
end
