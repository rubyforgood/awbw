class ReportsController < ApplicationController
  def show
    @report = Report.find(params[:id])
  end

  def monthly_select_type
  end

  def monthly
    build_month_and_year
    find_form_builder

    if (@report = current_user.submitted_monthly_report(@date,
                                                        @form_builder.windows_type))
      redirect_to( :action => :edit, :id => @report,
                   :month => @month, :year => @year,
                   :form_builder_id => @form_builder.id )
    else
      render_form
      render :new
    end
  end

  def share_story
    params[:form_builder_id] = 7
    render_form

    @report.owner_type = "FormBuilder"
    @report.owner_id   = 7
    @agencies = current_user.projects
  end

  def render_form
    @workshop_list = current_user.curriculum.
                       where(inactive: false).
                       order(title: :asc)

    build_month_and_year
    find_form_builder
    build_report
    build_report_form_fields
    find_workshop_logs
  end

  def edit
    build_month_and_year
    find_form_builder
    @report    = current_user.submitted_monthly_report( @date, @form_builder.windows_type )
    @agencies  = current_user.projects.
                 where(windows_type_id: @report.windows_type_id)
    @month = @report.date.month
    @year  =  @report.date.year

    find_workshop_logs
  end

  def edit_story
    @workshop_list    = current_user.curriculum.
                        where(inactive: false, windows_type: 3).order(title: :asc)

    @report    = Report.find(params[:id])
    @agencies  = current_user.projects.
                 where(windows_type_id: @report.windows_type_id)
  end

  def update_story
    @report = Report.find params[:id]

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
      redirect_to reports_edit_story_path(@report)
    end
  end

  def update
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

  def create
    build_new_report

    report_type = "story"
    report_type = "monthly report" unless @report.owner_id == 7

    if params[:sectorable_items] or params[:form_builder_id] == '7'
      if @report.save
        flash[:notice] = "Your #{report_type} has been successfully submitted."
        redirect_to '/'
      else
        @form_builder = FormBuilder.find( @report.owner_id )
        build_month_and_year

        flash[:alert] = "There was a problem submitting your form: " +
                        "#{@report.errors.full_messages.join(" ")}"

        redirect_to :action =>'new', :form_builder_id => @report.owner_id
      end
    else
      flash[:alert] = 'Please select some populations that attended this monthly report!!!'
      redirect_to "/reports/monthly?form_builder_id=#{params[:form_builder_id]}&year=#{params[:year]}&month=#{params[:month]}"
    end
  end

  def create_story
    build_new_report
    @report.type = "Story"
    @report.report_form_field_answers.build( log_fields )


    if !params[:workshop_id].empty?
      @report.windows_type_id = Workshop.find(@report.workshop_id).windows_type_id
    else
      @report.workshop_id = nil
      @report.windows_type_id = @report.project.windows_type_id
    end

    if @report.save
      flash[:notice] = "Your Story has been successfully submitted."
      redirect_to '/'
    else
      @form_builder = FormBuilder.find( @report.owner_id )
      build_month_and_year

      flash[:alert] = "There was a problem submitting your form: " +
                      "#{@report.errors.full_messages.join(" ")}"

      redirect_to :action =>'share_story', :form_bilder_id => @report.owner_id
    end
  end

  private

  def find_form_builder
    if params[:form_builder_id]
      @form_builder = FormBuilder.find( params[:form_builder_id] ).decorate
    else
      @form_builder = FormBuilder
        .monthly
        .find_by(windows_type_id: @agency.windows_type_id)
        .decorate
    end
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
    @report.image = Image.new( file: params[:image] ) unless params[:image].blank?

    quotes = []
    quotes_params.each{ |q|
      quotes << Quote.new( quote: q[:quote], age: q[:age], gender: q[:gender] )
    }

    @report.quotes = quotes

    @report.date = build_date
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
      :image, :form_file, :type, :project_id, :date, :workshop_name, :owner_id, :workshop_id,
      :owner_type, :windows_type_id, report_form_field_answers_attributes:
      [:form_field_id, :answer_option_id, :answer, :_create], media_files_attributes: [:file]
    )
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
