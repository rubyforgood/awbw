class RichTextMigrator
  include ActionText::ContentHelper

  PLACEHOLDER_TEXT = "image not found"

  def initialize(record, old_column)
    @record = record
    @old_column = old_column.to_s
    @new_column = "rhino_#{@old_column}"
    @blobs_by_key = index_resource_blobs
  end

  def migrate!
    html = @record.public_send(@old_column)
    return if html.blank?

    sanitized_html = sanitize_html(html)

    # Assign the rich text content dynamically
    @record.assign_attributes(@new_column => ActionText::Content.new(sanitized_html))

    # Save without triggering validations
    @record.save(validate: false)
  end

  private

  # ----------------------------
  # Sanitization
  # ----------------------------
  def sanitize_html(html)
    sanitized = ActionController::Base.helpers.sanitize(
      html,
      tags: allowed_tags,
      attributes: allowed_attributes
    )

    convert_images_to_attachments(sanitized)
  end

  def allowed_tags
    ActionText::ContentHelper.allowed_tags
  end

  def allowed_attributes
    ActionText::ContentHelper.allowed_attributes
  end

  # ----------------------------
  # Image conversion
  # ----------------------------
  def convert_images_to_attachments(html)
    fragment = Nokogiri::HTML::DocumentFragment.parse(html)

    fragment.css("img").each do |img|
      aws_key = extract_aws_key(img["src"])
      blob = @blobs_by_key[aws_key]

      if blob
        attachment = ActionText::Attachment.from_attachable(blob)
        img.replace(attachment.to_html)
      else
        img.replace(placeholder_node(img["alt"]))
      end
    end

    fragment.to_html
  end

  # ----------------------------
  # Blob lookup
  # ----------------------------
  def index_resource_blobs
    @record.images
      .includes(file_attachment: :blob)
      .map(&:file)                 # get ActiveStorage::Attached::One
      .map(&:blob)                 # may be nil
      .compact                     # remove nil blobs
      .index_by(&:aws_key)
  end

  def extract_aws_key(src)
    return if src.blank?

    uri = URI.parse(src)
    uri.path
      .sub(%r{^/}, "") # remove leading slash
      .split("?")
      .first
  rescue URI::InvalidURIError
    nil
  end

  # ----------------------------
  # Placeholder
  # ----------------------------
  def placeholder_node(alt = nil)
    text = alt.presence || PLACEHOLDER_TEXT

    Nokogiri::HTML::DocumentFragment.parse(
      "<span>#{ERB::Util.html_escape(text)}</span>"
    )
  end
end
