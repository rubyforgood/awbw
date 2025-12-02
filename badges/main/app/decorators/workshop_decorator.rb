# coding: utf-8
class WorkshopDecorator < Draper::Decorator
  delegate_all

  def created_by
    user
  end

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

  def main_image_url
    if main_image&.file&.attached?
      Rails.application.routes.url_helpers.url_for(main_image.file)
    elsif gallery_images.first&.file&.attached?
      Rails.application.routes.url_helpers.url_for(gallery_images.first.file)
    else
      ActionController::Base.helpers.asset_path("workshop_default.jpg")
    end
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
