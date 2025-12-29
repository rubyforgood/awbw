module ImageHelper
  def main_image_url(record)
    return nil unless record.present?

    # All possible attachment names used across your models
    attachment_candidates = [ "main_image", "avatar", "photo", "banner", "hero_image",
                             "gallery_images", "images", "attachments", "media_files" ]

    attachment_candidates.each do |name|
      next unless record.respond_to?(name)

      value = record.public_send(name)
      next if value.blank?

      # CASE 1 — Direct ActiveStorage attachment (e.g., user.avatar)
      if value.respond_to?(:attached?) && value.attached?
        return url_for(value)
      end

      # CASE 2 — Wrapper Model (e.g., StoryIdea.main_image)
      if value.respond_to?(:file) &&
        value.file.respond_to?(:attached?) &&
        value.file.attached?

        return url_for(value.file)
      end

      # CASE 3 — Collection (e.g., StoryIdea.gallery_images)
      # value = ActiveRecord::Associations::CollectionProxy each item is an Image STI instance
      if value.is_a?(Enumerable)
        img = value.find { |img| img.respond_to?(:file) &&
          img.file.respond_to?(:attached?) &&
          img.file.attached? }

        return url_for(img.file) if img
      end
    end

    nil
  end
end
