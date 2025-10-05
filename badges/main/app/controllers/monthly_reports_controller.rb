# frozen_string_literal: true

class MonthlyReportsController < ApplicationController
  def show
    @report = Report.find(params[:id])
  end

  def monthly_select_type
    check_feature_fag
  end

  def monthly
    check_feature_fag
    return if performed?

    build_month_and_year
    find_form_builder
    load_agencies
    @workshop_log_summary_page = show_feature?(:new_workshop_log)

    if (@report = current_user.submitted_monthly_report(@date,
                                                        @form_builder.windows_type,
                                                        @agency_id))
      redirect_to( :action => :edit, :id => @report,
                   :month => @month, :year => @year,
                   :form_builder_id => @form_builder.id, :agency_id => @agency_id )
    else
      render_form
      render :new
    end
  end

  def create
    check_feature_fag
    build_new_report

    if params[:sectorable_items]
      if @report.save
        flash[:notice] = "Your Monthly report has been successfully submitted."
        redirect_to '/'
      else
        @form_builder = FormBuilder.find( @report.owner_id )
        build_month_and_year
        load_agencies
        @agency_id = report_params['project_id']

        flash[:alert] = "There was a problem submitting your form: " +
                        "#{@report.errors.full_messages.join(" ")}"
        render :new
      end
    else
      flash[:alert] = 'Please select some populations that attended this monthly report!!!'

      @total_ongoing    = 0
      @total_first_time = 0

      find_form_builder
      #@report.report_form_field_answers.build( log_fields )
      render :new
    end
  end

  def edit
    check_feature_fag
    build_month_and_year
    find_form_builder
    @report = Report.find(params[:id])
    @agencies  = current_user.projects.
                 where(windows_type_id: @report.windows_type_id)
    @month = @report.date.month
    @year  =  @report.date.year

    find_workshop_logs
    find_combined_workshop_logs(@agency_id)
  end

  def update
    check_feature_fag
    @report = MonthlyReport.find params[:id]

    if params[:report]
      ActiveRecord::Base.transaction do
        @report.update_attributes( report_params )
        @saved = @report.delete_and_update_all( quotes_params, log_fields,
                                                params[:image] )
      end

      if @saved
        flash[:notice] = 'Thanks for reporting on a update report. '
        redirect_to authenticated_root_path
      else
        @agencies  = current_user.projects.
                       where(windows_type_id: @report.windows_type_id)

        flash[:alert] = 'ERROR!!!!!!!!!!!!!!'
        render :edit
      end
    else
      flash[:alert] = 'Please select some populations that attended this report!!!'
      redirect_to edit_report_path(@report)
    end
  end


  private

  def load_agencies
    @agencies  = current_user.projects.
                   where(windows_type_id: @form_builder.windows_type_id).uniq

  end

  def render_form
    @workshop_list = current_user.curriculum.
                       where(inactive: false, windows_type: 3).
                       order(title: :asc)

    build_month_and_year
    build_report
    find_form_builder
    build_report_form_fields
    find_workshop_logs
    find_combined_workshop_logs(@agency_id)
  end

  def find_form_builder
    if params[:form_builder_id]
      @form_builder = FormBuilder.find( params[:form_builder_id] ).decorate
    else
      @form_builder = FormBuilder
        .monthly
        .find_by(windows_type_id: @agency.windows_type_id)
        .decorate
    end

    agency     = params[:agency_id] ? Project.find(params[:agency_id]) : current_user.projects.where(windows_type_id: @form_builder.windows_type).first
    @agency_id = agency.id unless agency.nil?
  end

  def build_report
    @report = Report.new(
      type: @form_builder.report_type,
      windows_type: @form_builder.windows_type,
      date: @date
    )

    @report.media_files.build
  end

  def build_new_report
    @report = current_user.reports.build( report_params )
    @report.report_form_field_answers.build( log_fields )
    # @report.media_files.build( file: media_files_params ) unless media_files_params.blank?

    quotes = []
    quotes_params.each{ |q|
      quotes << Quote.new( quote: q[:quote], age: q[:age], gender: q[:gender] )
    }

    @report.quotes = quotes

    @report.date = build_date
  end

  def check_feature_fag
    redirect_to '/' if show_feature?(:no_monthly_reports)
  end

  def build_report_form_fields
    return unless @form_builder.form_fields

    @form_builder.form_fields.where(status: 1).each do |field|
      if field.multiple_choice?
        field.answer_options.each do |option|
          @report.report_form_field_answers.new(
            form_field: field,
            answer_option: option
          )
        end
      else
        @report.report_form_field_answers.new(
          form_field: field
        )
      end
    end
  end

  def find_workshop_logs
    @workshop_logs = current_user.project_monthly_workshop_logs(
      @report.date, @report.windows_type
    )

    logs = @workshop_logs.map{|k, v| v}.flatten
    @total_ongoing    = logs.reduce(0){|sum, l| sum = sum + l.num_ongoing}
    @total_first_time = logs.reduce(0) {|sum, l| sum = sum + l.num_first_time}
  end

  def find_combined_workshop_logs(agency_id)
    combined_windows_type = WindowsType.where("name LIKE ?", "%COMBINED (FAMILY)%").first
    @combined_workshop_logs = current_user.project_workshop_logs(
    @report.date, combined_windows_type, agency_id )
  end

  def build_month_and_year
    @month = params[:month] ? params[:month] : Date.current.month
    @year  = params[:year] ? params[:year] : Date.current.year
    @date  = Date.new( @year.to_i, @month.to_i )
  end

  def report_params
    params[:report].delete(:form_file) if params[:report][:form_file].blank?

    params[:report][:media_files_attributes].each do |k,v|
      params[:report][:media_files_attributes].delete(k) if params[:report][:media_files_attributes][k][:file].blank?

    end

    params.require(:report).permit(
      :type, :project_id, :date, :owner_id, :workshop_id,
      :owner_type, :windows_type_id, :other_description,
      media_files_attributes: [:file],
      report_form_field_answers_attributes:
        [:form_field_id, :answer_option_id, :answer, :_create]
    )
  end

  def media_files_params
    params[:report].require(:media_files_attributes)
  end

  def log_fields
    log_fields_params.map do |k, v|
      { :form_field_id => k, :answer => v, :report_id => @report.id }
    end
  end

  def log_fields_params
    params.require(:log_fields)
  end

  def quotes_params
    return [] if params[:quotes].nil?
    params[:quotes].permit!.map{|k, v| v}
  end

  def build_date
    @month = Date.current.month
    @year  = Date.current.year
    @date = params[:report][:date] ?
              Date.strptime( params[:report][:date], '%Y-%m' ) :
              Date.new( @year.to_i, @month.to_i )
  end

end
