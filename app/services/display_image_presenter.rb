# frozen_string_literal: true

class DisplayImagePresenter
  WIDTH_CLASSES = {
    "18" => "w-18", "24" => "w-24", "32" => "w-32", "full" => "w-full"
  }.freeze

  HEIGHT_CLASSES = {
    "14" => "h-14", "18" => "h-18", "24" => "h-24", "32" => "h-32", "full" => "h-full"
  }.freeze

  PDF_PREVIEW_SIZES = { hero: [ 1200, 1200 ], gallery: [ 300, 300 ], index: [ 300, 300 ] }.freeze

  Result = Struct.new(
    :display_type, :renderable, :alt_text, :image_classes, :wrapper_classes,
    :link_href, :link_options, :show_pdf_link, :pdf_link_path, :filename,
    keyword_init: true
  )

  def self.call(**args)
    new(**args).call
  end

  def initialize(resource: nil, item: nil, file: nil, field_name: :primary_asset,
                 variant: :gallery, width: "32", height: nil,
                 link: nil, link_to_object: false, display_open_pdf_link: false,
                 idx: 0, item_type: "PrimaryAsset", extra_image_classes: "",
                 view_context:)
    @resource = resource
    @item = item
    @file = file || item&.file || resource&.try(field_name)&.file
    @variant = variant
    @width = width.to_s
    @height = (height || width).to_s
    @link_to_object = link_to_object
    @link = link.nil? ? link_to_object : link
    @display_open_pdf_link = display_open_pdf_link
    @idx = idx
    @item_type = item_type
    @extra_image_classes = extra_image_classes
    @view_context = view_context
  end

  def call
    type = resolve_display_type
    return Result.new(display_type: :none) if type == :none

    Result.new(
      display_type: type,
      renderable: resolve_renderable(type),
      alt_text: build_alt_text(type),
      image_classes: build_image_classes(type),
      wrapper_classes: build_wrapper_classes,
      link_href: @link ? resolve_link_href(type) : nil,
      link_options: build_link_options,
      show_pdf_link: show_pdf_link?,
      pdf_link_path: show_pdf_link? ? @view_context.rails_blob_path(@file, disposition: :inline) : nil,
      filename: as_file? ? blob&.filename.to_s : nil
    )
  end

  private

  def resolve_display_type
    if @file.is_a?(Symbol)
      :icon
    elsif as_file?
      if !@file.previewable? && pdf? && @variant != :hero
        :pdf_document
      else
        :active_storage
      end
    elsif @file.is_a?(String)
      :fallback
    else
      :none
    end
  end

  def resolve_renderable(type)
    case type
    when :active_storage then resolve_active_storage_renderable
    when :fallback then @file
    end
  end

  def resolve_active_storage_renderable
    if @file.previewable?
      resolve_previewable
    elsif @variant == :hero
      @file
    elsif use_thumbnail?
      @file.variant(:thumbnail)
    else
      @file
    end
  end

  def resolve_previewable
    if pdf?
      preview_size = PDF_PREVIEW_SIZES.fetch(@variant, [ 300, 300 ])
      @file.preview(resize_to_limit: preview_size)
    elsif use_thumbnail?
      @file.variant(:thumbnail)
    else
      @file.preview(resize_to_limit: PDF_PREVIEW_SIZES.fetch(@variant, [ 300, 300 ]))
    end
  end

  def use_thumbnail?
    (@variant == :index || @variant == :gallery || small_dimensions?) && @file.variable?
  end

  def small_dimensions?
    @width.to_i > 0 && @width.to_i <= 32 && @height.to_i > 0 && @height.to_i <= 32
  end

  def build_alt_text(type)
    case type
    when :active_storage
      label = @file.previewable? ? "preview" : "image"
      "#{@item_type} #{label} #{@idx + 1} (#{blob&.filename})"
    when :fallback
      "#{@item_type} fallback image #{@idx + 1}"
    end
  end

  def build_image_classes(type)
    w = WIDTH_CLASSES.fetch(@width, "w-auto")
    h = HEIGHT_CLASSES.fetch(@height, "h-auto")
    object_fit = pdf? ? "object-contain bg-gray-100" : "object-cover"

    base = case @variant
    when :hero
      "hero-size w-full rounded-lg shadow-sm border border-gray-200 #{@extra_image_classes}"
    when :gallery
      "gallery-size #{w} #{h} #{object_fit} rounded border border-gray-300 shadow-sm hover:opacity-90 transition-opacity #{@extra_image_classes}"
    when :index
      "w-full h-full #{object_fit} #{@extra_image_classes}"
    end

    if type == :active_storage
      "#{base} hover:opacity-95 transition-opacity"
    else
      base
    end
  end

  def build_wrapper_classes
    w = WIDTH_CLASSES.fetch(@width, "w-auto")
    h = HEIGHT_CLASSES.fetch(@height, "h-auto")

    case @variant
    when :hero then "mb-8"
    when :gallery then "flex grow"
    when :index then "index-size #{w} #{h} shrink-0 overflow-hidden rounded border border-gray-300"
    end
  end

  def resolve_link_href(type)
    if @link_to_object && @resource
      @view_context.polymorphic_path(@resource)
    elsif type == :active_storage
      @view_context.url_for(@file)
    elsif type == :icon
      nil
    else
      @view_context.asset_path(@file)
    end
  end

  def build_link_options
    if @link_to_object
      { class: "display-image-link", data: { turbo_frame: "_top", turbo_prefetch: false } }
    else
      { class: "display-image-link", target: "_blank", rel: "noopener noreferrer" }
    end
  end

  def show_pdf_link?
    @display_open_pdf_link && as_file? && @file.previewable? && pdf?
  end

  def as_file?
    return false if @file.is_a?(Symbol)
    return true if @file.respond_to?(:attached?) && @file.attached?
    @file.is_a?(ActiveStorage::Blob) || @file.is_a?(ActiveStorage::Attachment)
  end

  def blob
    @file.respond_to?(:blob) ? @file.blob : @file
  end

  def pdf?
    @file.respond_to?(:content_type) && @file.content_type == "application/pdf"
  end
end
