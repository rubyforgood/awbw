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

    @record.assign_attributes(@new_column => ActionText::Content.new(sanitized_html))

    @record.save(validate: false)
  end

  private

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

  def convert_images_to_attachments(html)
    fragment = Nokogiri::HTML::DocumentFragment.parse(html)

    fragment.css("img").each do |img|
      aws_key = extract_aws_key(img["src"])
      blob = @blobs_by_key[aws_key]

      if blob
        attachment = ActionText::Attachment.from_attachable(blob)
        img.replace(attachment.to_html)
      else
        img.replace(placeholder_node(img["src"]))
      end
    end

    fragment.to_html
  end

  def index_resource_blobs
    @record.images
      .includes(file_attachment: :blob)
      .map(&:file)                 # get ActiveStorage::Attached::One
      .map(&:blob)
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

  def placeholder_node(src = nil)
    text = %([#{PLACEHOLDER_TEXT}#{": #{src}" if src.present?}])

    Nokogiri::HTML::DocumentFragment.parse(
      "<span>#{ERB::Util.html_escape(text)}</span>"
    )
  end
end
