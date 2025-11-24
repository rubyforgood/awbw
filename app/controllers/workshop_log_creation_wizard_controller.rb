class WorkshopLogCreationWizardController < ApplicationController
  include Wicked::Wizard

  steps :choose_method, :fill_out_form, :confirmation
  before_action :set_breadcrumb

  def show
    @user = current_user
    @agencies = current_user.projects
    windows_type_id = params[:windows_type_id] || current_user.windows_types.first.id
    @windows_type = WindowsType.find(windows_type_id) if windows_type_id
    send(step)
    render_wizard
  end

  def update
    @user = current_user
    @agencies = current_user.projects
    windows_type_id = params['workshop']['workshop_logs_attributes'].values[0]['windows_type_id']
    @windows_type = WindowsType.find(windows_type_id)
    send("update_#{step}")
    render_wizard unless @new_workshop
  end

  private

  def choose_method
  end

  def fill_out_form
    load_workshop
    load_previous_report
    load_workshop_log
    build_workshop_sectors
    # build_workshop_age_ranges
    build_report_form_field_answers
    build_workshop_quote
    @agencies = @agencies.where(windows_type: @workshop.windows_type) if @workshop.windows_type
  end

  def load_previous_report
    if id_param
      @old_report = Report.find_by(id: id_param)
      date_array = @old_report.date.to_s.split('-')
      @date = date_array[1] + '-' + date_array[2] + '-' + date_array[0]
    end
  end

  def update_fill_out_form
    puts id_param
    old_report = Report.find_by(id: id_param)
    if old_report
      ReportFormFieldAnswer.where(report: old_report).delete_all
      old_report.delete
    end
    find_or_build_workshop
    if @workshop.save
      if @new_workshop
        flash[:notice] = 'Thanks for reporting on a new workshop.  Please fill out the workshop details below.'
        redirect_to edit_workshop_path(@workshop)
      else
        jump_to(:confirmation, workshop_id: @workshop.id)
      end
    else
      build_workshop_sectors
    end
  end

  def confirmation
    load_workshop
  end

  def load_workshop
    if workshop_id_param
      @workshop = Workshop.find_by_id(workshop_id_param).decorate
      @related_workshops = @workshop.related_workshops
    else
      @windows_types = @user.windows_types
      @workshop = @user.workshops.build(
        windows_type: @windows_type ? @windows_type : @windows_types[0]
      ).decorate
    end
  end

  def find_or_build_workshop
    unless workshop_id_param.blank?
      @workshop = Workshop.find(workshop_id_param).decorate
      @workshop.update(
        workshop_params
      )
      @related_workshops = @workshop.related_workshops
    else
      @new_workshop = true
      @workshop = current_user.workshops.build(
        workshop_params
      ).decorate
    end
  end

  def build_workshop_sectors
    explored_sectors = []
    @workshop.sectors.build
    Sector.published.each do |sector|
      #byebug
      unless @workshop.sectorable_items.map(&:sector_id).include?(sector.id)
        @workshop.sectorable_items.build(sector_id: sector.id)
      end
    end
  end

  def build_workshop_age_ranges
    @workshop.windows_type.age_ranges.each do |range|
      @workshop.workshop_age_ranges.build(age_range: range)
    end
  end

  def build_report_form_field_answers
    @workshop.workshop_log_fields.each do |field|
      if field.multiple_choice?
        field.answer_options.each do |option|
          @workshop_log.report_form_field_answers.build(
            form_field: field,
            answer_option: option
          )
        end
      else
        @workshop_log.report_form_field_answers.build(
          form_field: field
        )
      end
    end
  end

  def build_workshop_quote
    @workshop.quotes.build
  end

  def workshop_sector_params
    params[:workshop_sectors]
  end

  def workshop_id_param
    params[:workshop] ? params[:workshop][:id] : params[:workshop_id]
  end

  def id_param
    if params[:log_id]
      params[:log_id]
    elsif params[:workshop] and params[:workshop][:log_id]
      params[:workshop][:log_id]
    end
  end

  def load_workshop_log
    @workshop_log = @workshop.workshop_logs.build(user_id: @user.id)
  end

  def workshop_params
    adjust_date
    params.require(:workshop).permit(
      :title, :date, :windows_type_id,
      workshop_logs_attributes: [:user_id, :rating, :reaction, :similarities, :is_embodied_art_workshop,
                                 :successes, :challenges, :differences, :date,
                                 :suggestions, :questions, :lead_similar, :project_id,
                                 :num_participants_on_going, :num_participants_first_time,
                                 report_form_field_answers_attributes:
                                  [:form_field_id, :answer_option_id, :answer, :_create]
                                ],
      #sectorable_items_attributes: [:_create, :sector_id, :is_leader],
      #sectors_attributes: [:_create, :name],
      workshop_age_ranges_attributes: [:age_range_id, :workshop_id, :_create],
      quotes_attributes: [:quote, :age],
    )
  end

  def adjust_date
    date = sent_date.split('-')
    if date.count > 2
      new_date = date[1] + '-' + date[0] + '-' + date[2]
      params["workshop"]["workshop_logs_attributes"][date_index]["date"] = new_date
    end
  end

  def sent_date
    hash = params["workshop"]["workshop_logs_attributes"]
    index = date_index
    if index.present?
      puts index
      return hash[index]["date"]
    else
      return ''
    end
  end

  def date_index
    index = nil
    hash = params["workshop"]["workshop_logs_attributes"]
    (0..100).each do |i|
      i = i.to_s
      if hash.has_key?(i) and hash[i].has_key?("date")
        index = i
        break
      end
    end
    return index
  end

  def set_breadcrumb
    @breadcrumb = params[:breadcrumb]
  end
end
