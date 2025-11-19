# coding: utf-8
class WorkshopDecorator < Draper::Decorator
  delegate_all

  def disable_title_field?
    !id.nil?
  end

  def field_has_empty_value?(field)
    send(field).nil? || send(field).empty?
  end

  def has_spanish_fields?
    spanish_field_values.any?
  end

  def new?
    (Date.today.year - year <= 1) if year
  end

  def sector_has_name?(form)
    form.object.name
  end

  def breadcrumbs
    if title
      "#{breadcrumbs_title} >> #{breadcrumb_link} >> Workshop Log".html_safe
    else
      "Submit Workshop Log >> Report on a New Workshop"
    end
  end

  def breadcrumb_link
    return title unless id
    h.link_to title, h.workshop_path(self), class: 'underline'
  end

  def breadcrumbs_title
    h.link_to 'Workshops', h.workshops_path, class: 'underline'
  end

  def detail_breadcrumbs
    "#{breadcrumbs_title} >> #{breadcrumb_link}".html_safe
  end

  def author
    "#{full_name}"
  end

  def title_with_badges(controller_name:)
    h.content_tag :div, class: "flex flex-col" do

      # -------------------------
      # BADGE ROW (row 1)
      # -------------------------
      badge_row = h.content_tag :div, class: "flex flex-wrap items-center gap-2 mb-1" do
        parts = []

        # Hidden badge
        if inactive? && controller_name != "dashboard"
          parts << h.content_tag(
            :span,
            h.content_tag(:i, "", class: "fa-solid fa-eye-slash mr-1") + " Hidden",
            class: "inline-flex items-center px-2 py-0.5 rounded-full
                  text-sm font-medium bg-blue-100 text-gray-600 whitespace-nowrap"
          )
        end

        # Featured badge
        if featured? && controller_name != "dashboard"
          parts << h.content_tag(
            :span,
            "🌟 Featured",
            class: "inline-flex items-center px-2 py-0.5 rounded-full
                  text-sm font-medium bg-yellow-100 text-yellow-800 whitespace-nowrap"
          )
        end

        parts.join.html_safe
      end

      # -------------------------
      # TITLE + WINDOWS TYPE (row 2)
      # -------------------------
      title_content = object.title

      if object.windows_type.present?
        title_content += " (#{object.windows_type.short_name})"
      end

      title_row = h.content_tag(
        :span,
        title_content.html_safe,
        class: "text-lg font-semibold text-gray-900 leading-tight"
      )

      # -------------------------
      # RETURN FINAL COMBINED ELEMENT
      # -------------------------
      (badge_row + title_row).html_safe
    end
  end




  def list_sectors
    sectorable_items.published.map(&:sector).map(&:name).to_sentence
  end

  def log_fields
    form_builder ? form_builder.forms[0].form_fields : []
  end

  def log_form_header
    if title
      "Workshop Log"
    else
      "Report on a New Workshop"
    end
  end

  def rating_as_stars
    full_star = '<i class="fas fa-star text-yellow-400"></i>'
    empty_star = '<i class="far fa-star text-gray-300"></i>'

    stars = full_star * rating + empty_star * (5 - rating)
    stars.html_safe
  end



  def display_objective
    if legacy
      html = html_objective
      html.xpath("//img").each do |img|
        src = formatted_url(img)
        img.set_attribute('src', src)
      end
      html.xpath("//a").each do |link|
        href = link.attributes['href'].value.gsub('https://www.awbw.org', 'http://dashboard.awbw.org') if link.attributes['href']
        link.set_attribute('href', href)
        link.set_attribute('class', 'underline')
      end
      html.to_s.html_safe
    else
      objective
    end
  end

  def formatted_url(img)
    return unless img.attributes['src']
    value = img.attributes['src'].value

    if value.include?('awbw.org')
      return value.gsub('https', 'http').gsub('www.', '').gsub('awbw.org', 'dashboard.awbw.org')
    else
      if value.include?("s3.amazonaws.com")
        return value
      else
        return value.prepend('http://dashboard.awbw.org') unless value.include?('.org') || value.include?('.com')
      end
    end
  end

  def formatted_objective(length: 100)
    if legacy
      html = html_objective

      html.search('.TextHeader2').each do |header|
        header.children.remove
      end

      obj = html.text.split("Objectives:")[1]
      obj ||= html.text.split("Objective:")[1]
      obj ||= html.text

      h.truncate(obj.gsub(title, '').
          gsub(/(Heart Story Example|Table set-up)/, '').squish, length: length)
    else
      h.truncate(html_objective.text.html_safe.squish, length: length)
    end
  end




  def objective_fixed_img_urls
    html = html_objective

    html.xpath("//img").each do |img|
      src = formatted_url(img)
      img.set_attribute('src', src)
    end

    html.to_s.html_safe
  end

  def dashboard_image_url
    if thumbnail&.attached?
      Rails.application.routes.url_helpers.url_for(thumbnail)
    elsif header&.attached?
      Rails.application.routes.url_helpers.url_for(header)
    elsif images&.first&.file&.attached?
      Rails.application.routes.url_helpers.url_for(images.first.file)
    else
      default_image_url
    end
  end

  def header_image
    if header.attached?
      header
    elsif thumbnail.attached?
      thumbnail
    end
  end

  def main_image
    content = html_content

    if content.css('img').any?
      images = html_objective.css('img')

      return nil unless images.any?

      pathname = images.map do |img|
        src = img.attributes['src'].value
        src unless src.include?('transparent')
      end.compact.first

      if pathname
        "https://dashboard.awbw.org#{pathname}"
      else
        "/images/workshop_default.jpg"
      end
    else
      images ? images.first.file : "/images/workshop_default.jpg"
    end
  end

  def thumbnail_image
    # TODO Figure out if we need main_image
    if thumbnail.attached?
      thumbnail
    elsif header.attached?
      header
    end
  end



  def spanish_field_values
    display_spanish_fields.map do |field|
      workshop.send(field) unless workshop.send(field).blank?
    end.compact
  end


  def display_fields
    [:objective, :materials, :optional_materials, :timeframe,
     :age_range, :setup, :introduction, :demonstration,
     :opening_circle, :warm_up,
     :visualization, :creation, :closing, :notes, :tips, :misc1, :misc2
    ]
  end

  def display_spanish_fields
    [
      :objective_spanish, :materials_spanish, :optional_materials_spanish,
      :age_range_spanish, :setup_spanish,
      :introduction_spanish, :demonstration_spanish, :opening_circle_spanish,
      :warm_up_spanish, :visualization_spanish, :creation_spanish,
      :closing_spanish, :notes_spanish, :tips_spanish, :misc1_spanish,
      :misc2_spanish, :extra_field_spanish # :timeframe_spanish,
    ]
  end

  def labels_spanish
    {
      objective_spanish: 'Objectivo',
      materials_spanish: 'Materiales',
      optional_materials_spanish: 'Materiales Opcionales',
      timeframe_spanish: 'Periodo de tiempo',
      age_range_spanish: 'Rango de edad',
      setup_spanish: 'Preparativos',
      introduction_spanish: 'Introducción',
      demonstration_spanish: 'Demostración',
      opening_circle_spanish: 'Círculo de apertura',
      visualization_spanish: 'Visualización',
      warm_up_spanish: 'Comenzando',
      creation_spanish: 'Creación',
      closing_spanish: 'Clausura',
      misc_instructions_spanish: 'Instrucciones de misceláneos',
      project_spanish: 'Projecto',
      description_spanish: 'Descripción',
      notes_spanish: 'Notas',
      tips_spanish: 'Consejos',
      misc1_spanish: 'Misc 1',
      misc2_spanish: 'Misc 2'
    }
  end



  private

  def html_content
    Nokogiri::HTML("#{objective} #{materials} #{timeframe} #{setup} #{workshop.introduction}")
  end

  def html_objective
    Nokogiri::HTML(objective)
  end
end
