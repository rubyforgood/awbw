class RichTextMigrator
  include Rails.application.routes.url_helpers

  require "nokogiri"
  require "uri"

  PLACEHOLDER_TEXT = "image not found"

  def initialize(record, old_column)
    @record = record
    @old_column = old_column.to_s
    @new_column = "rhino_#{@old_column}"
  end

  def migrate!
    return unless valid_columns?

    html = @record.public_send(@old_column)
    return if html.blank?

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)

    fragment.css("img").each do |img|
      img_url = img["src"]
      next unless img_url

      signed_id = extract_signed_id(img_url)
      next unless signed_id

      blob = find_blob(signed_id)
      if blob
        attachment = ActionText::Attachment.from_attachable(blob, url: url_for(blob))

        img.replace(attachment.to_html)
      else
        img.replace(placeholder_node(img_url))
      end
    end

    @record.public_send(@new_column).update!(body: fragment.to_html)
  end

  private

  def valid_columns?
    @record.respond_to?(@old_column) && @record.respond_to?(@new_column)
  end

  def extract_signed_id(url)
    path_segments = URI.parse(url).path.split("/blobs/")[1]&.split("/")
    return nil unless path_segments

    (path_segments.first == "redirect") ? path_segments[1] : path_segments.first
  rescue
    nil
  end

  def find_blob(signed_id)
    ActiveStorage::Blob.find_signed(signed_id)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def placeholder_node(src = nil)
    text = %([#{PLACEHOLDER_TEXT}#{": #{src}" if src.present?}])

    Nokogiri::HTML::DocumentFragment.parse(
      "<span>#{ERB::Util.html_escape(text)}</span>"
    )
  end
end
