module ApplicationHelper

  def root_link_path
    user_signed_in? ? authenticated_root_path : unauthenticated_root_path
  end

  def search_page(params)
    params[:search] ? params[:search][:page] : 1
  end

  def checked?(param = false)
    param == '1'
  end

  def months_with_year
    (1..12).collect{ |m| "#{m}/#{today.year}"}
  end

  def current_month_with_year
    today.strftime("%_m/%Y")
  end

  def current_year
    today.year
  end

  def today
    Date.today
  end

  def display_banner
    banners = Banner.all
    return unless banners.any?(&:show)

    safe_content_array = []

    banners.published.each do |banner|
      safe_content_array << sanitize(
        banner.content,
        tags: %w[a],
        attributes: %w[href]
      )
    end

    safe_content = safe_content_array.join("<br>")

    content_tag(:div, id: "banner-news", class: "bg-yellow-200 text-black text-center px-4 py-2") do
      content_tag(:div, safe_content.html_safe, class: "font-medium")
    end
  end

  def main_image_url(record)
    return nil unless record.present?

    # All possible attachment names used across your models
    attachment_candidates = ["main_image", "avatar", "photo", "banner", "hero_image",
                             "gallery_images", "images", "attachments", "media_files"]

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

  def ra_path(obj, action = nil)
    action = action.nil? ? '' : "#{action}_"

    if obj.form_builder and obj.form_builder.name == "Share a Story"
      if action.empty?
       return report_path(obj)
      else
        return send("reports_#{action}story_path", obj)
      end
    end

    unless obj.respond_to? :type
      if action.empty?
        return share_idea_show_path(obj)
      else
        return edit_workshop_path(obj)
      end
    end

    if obj.type == "WorkshopLog"
      send("#{action}workshop_log_path", obj)
    elsif obj.type != "WorkshopLog" and action == 'edit_'
      send("#{action}report_path", obj, form_builder_id: obj.form_builder,
           month: obj.date.month,
           year: obj.date.year)
    else
      send("#{action}report_path", obj)
    end
  end

  def sortable_field_display_name(name)
    case name
    when :adult
      'Adult Windows'
    when :children
      'Children\'s Windows'
    else
      name.to_s.titleize
    end
  end

  def title_with_badges(record, admin: false, display_windows_type: false)
    content_tag :div, class: "flex flex-col" do

      # ---- BADGE ROW ---------------------------------------------------------
      badge_row = content_tag :div, class: "flex flex-wrap items-center gap-2 mb-1" do
        fragments = []

        # Hidden badge
        if admin && record.respond_to?(:inactive?) &&
          record.inactive? && controller_name != "dashboard"
          fragments << content_tag(
            :span,
            content_tag(:i, "", class: "fa-solid fa-eye-slash mr-1") + " Hidden",
            class: "inline-flex items-center px-2 py-0.5 rounded-full
                  text-sm font-medium bg-blue-100 text-gray-600 whitespace-nowrap"
          )
        end

        # Featured badge
        if record.respond_to?(:featured?) &&
          record.featured? && controller_name != "dashboard"
          fragments << content_tag(
            :span,
            "🌟 Featured",
            class: "inline-flex items-center px-2 py-0.5 rounded-full
                  text-sm font-medium bg-yellow-100 text-yellow-800 whitespace-nowrap"
          )
        end

        safe_join(fragments)
      end

      # ---- TITLE + WINDOWS TYPE ------------------------------------------------
      title_content = record.title.to_s

      if display_windows_type && record.respond_to?(:windows_type) && record.windows_type.present?
        title_content += " (#{record.windows_type.short_name})"
      end

      title_row = content_tag(
        :span,
        title_content.html_safe,
        class: "text-lg font-semibold text-gray-900 leading-tight"
      )

      # Combine badge row + title row
      safe_join([badge_row, title_row])
    end
  end


  def icon_for_mimetype(mime)
    mimes = {
        'image' => 'fa-file-image',
        'audio' => 'fa-file-audio',
        'video' => 'fa-file-video',
        # Documents
        'application/pdf' => 'fa-file-pdf',
        'application/msword' => 'fa-file-word',
        'application/vnd.ms-word' => 'fa-file-word',
        'application/vnd.oasis.opendocument.text' => 'fa-file-word',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'fa-file-word',
        'application/vnd.ms-excel': 'fa-file-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 'fa-file-excel',
        'application/vnd.oasis.opendocument.spreadsheet' => 'fa-file-excel',
        'application/vnd.ms-powerpoint' => 'fa-file-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml' => 'fa-file-powerpoint',
        'application/vnd.oasis.opendocument.presentation' => 'fa-file-powerpoint',

        # Archives
        'application/gzip' => 'fa-file-archive',
        'application/zip' => 'fa-file-archive',
    }

    if mime
      m = mimes[mime.split('/').first]
      m ||= mimes[mime]
    end

    m ||= 'fa-file'

    "fas #{m}"
  end

  def display_count(value)
    value.to_i.zero? ? "--" : number_with_delimiter(value)
  end
end
