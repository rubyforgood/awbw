module ApplicationHelper
  def search_page(params)
    params[:search] ? params[:search][:page] : 1
  end

  def checked?(param = false)
    param == "1"
  end

  def months_with_year
    (1..12).collect { |m| "#{m}/#{today.year}" }
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
    # Cache banners to avoid repeated queries during page render
    @banners ||= Banner.published.select("id, content").to_a
    return if @banners.empty?

    safe_content_array = @banners.map { |banner|
      sanitize(
        banner.content,
        tags: %w[a],
        attributes: %w[href]
      )
    }

    safe_content = safe_content_array.join("<br>")

    content_tag(:div, id: "banner-news", class: "bg-yellow-200 text-black text-center px-4 py-2") do
      content_tag(:div, safe_content.html_safe, class: "font-medium")
    end
  end

  def ra_path(obj, action = nil)
    action = action.nil? ? "" : "#{action}_"

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
    elsif obj.type != "WorkshopLog" and action == "edit_"
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
      "Adult Windows"
    when :children
      "Children's Windows"
    else
      name.to_s.titleize
    end
  end

  def icon_for_mimetype(mime)
    mimes = {
        "image" => "fa-file-image",
        "audio" => "fa-file-audio",
        "video" => "fa-file-video",
        # Documents
        "application/pdf" => "fa-file-pdf",
        "application/msword" => "fa-file-word",
        "application/vnd.ms-word" => "fa-file-word",
        "application/vnd.oasis.opendocument.text" => "fa-file-word",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => "fa-file-word",
        'application/vnd.ms-excel': "fa-file-excel",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => "fa-file-excel",
        "application/vnd.oasis.opendocument.spreadsheet" => "fa-file-excel",
        "application/vnd.ms-powerpoint" => "fa-file-powerpoint",
        "application/vnd.openxmlformats-officedocument.presentationml" => "fa-file-powerpoint",
        "application/vnd.oasis.opendocument.presentation" => "fa-file-powerpoint",

        # Archives
        "application/gzip" => "fa-file-archive"
    }

    if mime
      m = mimes[mime.split("/").first]
      m ||= mimes[mime]
    end

    m ||= "fa-file"

    "fas #{m}"
  end

  def display_count(value)
    value.to_i.zero? ? "--" : number_with_delimiter(value)
  end

  def navbar_bg_class
    staging_environment? ? "bg-red-600" : "bg-primary"
  end

  def staging_environment?
    ENV["RAILS_ENV"] == "staging" || Rails.env == "staging"
  end

  def favicon_file
    case Rails.env.to_s
    when "production"
      "logo-circle.png"
    when "staging"
      "favicon.png"
    else
      "theme_default.png"
    end
  end

  def email_confirmation_icon(user)
    if user.unconfirmed_email.present?
      content_tag(:span, "pending confirmation", class: "text-yellow-600 font-medium", title: "Email change pending confirmation")
    elsif user.confirmed_at.present?
      content_tag(:span, "confirmed", class: "text-green-600 font-medium", title: "Email confirmed")
    else
      content_tag(:span, "unconfirmed", class: "text-red-600 font-medium", title: "Email not confirmed")
    end
  end

  def email_label_with_confirmation_icon(user)
    "Email #{email_confirmation_icon(user)}".html_safe
  end

  # Returns checkbox options for the visibility filter dropdown.
  # Each entry is [label, param_name, admin_only].
  # Options adapt to the model's columns and the user's role.
  def visibility_filter_options(model_class, admin:, authenticated:)
    cols = model_class.column_names
    options = []

    if admin
      options << [ "Published", :published, true ]
      options << [ "Unpublished", :unpublished, true ]
      options << [ "Featured", :featured, false ]             if cols.include?("featured")
      options << [ "Publicly Visible", :publicly_visible, false ] if cols.include?("publicly_visible")
      options << [ "Publicly Featured", :publicly_featured, false ] if cols.include?("publicly_featured")
    elsif authenticated
      options << [ "Not Featured", :not_featured, false ]     if cols.include?("featured")
      options << [ "Featured", :featured, false ]             if cols.include?("featured")
      options << [ "Publicly Visible", :publicly_visible, false ] if cols.include?("publicly_visible")
      options << [ "Publicly Featured", :publicly_featured, false ] if cols.include?("publicly_featured")
    else
      options << [ "Not Publicly Featured", :not_publicly_featured, false ] if cols.include?("publicly_featured")
      options << [ "Publicly Featured", :publicly_featured, false ]         if cols.include?("publicly_featured")
    end

    options
  end

  # Fundamental US time zones only (for user preference dropdown).
  # Order: Eastern → Pacific, then Alaska, Hawaii, Arizona.
  def default_organization_for_form(object)
    return object.organization if object.organization.present?

    if current_user.super_user?
      Organization.find_by(name: ENV["ORGANIZATION_NAME"])
    elsif current_user.person&.affiliations&.count == 1
      current_user.person.primary_organization
    end
  end

  def custom_caret_style
    "background-image:url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%236b7280' d='M2 4l4 4 4-4'/%3E%3C/svg%3E\");background-position:right 0.75rem center;background-size:12px;background-repeat:no-repeat;"
  end

  def select_caret_class(blank:)
    "w-full px-3 py-2 pr-10 border border-gray-300 rounded-lg appearance-none #{"select-placeholder" if blank}"
  end

  def select_caret_onchange
    "if(this.value){this.classList.remove('select-placeholder')}else{this.classList.add('select-placeholder')}"
  end

  def hidden_fields_for_params(hash, prefix = nil)
    return "".html_safe if hash.blank?

    fields = []
    hash.each do |key, value|
      field_name = prefix ? "#{prefix}[#{key}]" : key.to_s
      case value
      when ActionDispatch::Http::UploadedFile
        next
      when Hash
        fields << hidden_fields_for_params(value, field_name)
      when Array
        value.each_with_index do |item, i|
          if item.is_a?(Hash)
            fields << hidden_fields_for_params(item, "#{field_name}[#{i}]")
          else
            fields << tag.input(type: "hidden", name: "#{field_name}[]", value: item)
          end
        end
      else
        next if key.to_s == "id" && value.blank?
        fields << tag.input(type: "hidden", name: field_name, value: value)
      end
    end
    safe_join(fields)
  end

  def us_time_zone_fundamentals
    zone_names = [
      "Eastern Time (US & Canada)",
      "Central Time (US & Canada)",
      "Mountain Time (US & Canada)",
      "Pacific Time (US & Canada)",
      "Alaska",
      "Hawaii",
      "Arizona"
    ]
    ActiveSupport::TimeZone.us_zones.select { |z| zone_names.include?(z.name) }.sort_by { |z| zone_names.index(z.name) }.map { |z| [ z.to_s, z.name ] }
  end
end
