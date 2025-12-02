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
