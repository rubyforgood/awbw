class WorkshopLogsController < ApplicationController
  def new
    params[:windows_type_id] = 1;
    @title = :title
    @agency_title = :name
    @agencies = current_user.projects.uniq
    @workshop_list = current_user.curriculum.where(inactive: false, windows_type_id: params[:windows_type_id])
                         .order(title: :asc)

    agency = params[:agency_id] && params[:agency_id] != '' ? Project.find(params[:agency_id]) : @agencies.first
    @agency_id = agency.id unless agency.nil?

    if params[:workshop_id]
      @workshop = Workshop.find( params[:workshop_id] )
    end

    if params[:windows_type_id]
      @workshop = Workshop.new(windows_type_id: params[:windows_type_id])
    end

  end

  def update
    set_default_values
    @workshop_log = WorkshopLog.find params[:id]

    ActiveRecord::Base.transaction do
      @workshop_log.update_attributes( wsl_params )

      @saved = @workshop_log.delete_and_update_all(quotes_params, log_fields)
    end

    if @saved
      files_params.each do |file|
        file = MediaFile.new(file: file)
        file.update(report_id: @workshop_log.id, owner_type: @workshop_log.owner_type, owner_id: @workshop_log.owner_id)
        file.save
      end
      flash[:alert] = 'Thanks for reporting on a new workshop. '
      redirect_to root_path
    else
      flash[:alert] = 'ERROR!'
      render :edit
    end
  end

  def create
    set_default_values
    @agencies = current_user.projects.uniq
    unless params[:workshop_id].empty?
      @workshop = Workshop.find(params[:workshop_id])
    end

    @title = params[:windows_type_id] == '3' ? :log_title : :title
    @agency_title = params[:windows_type_id] == '3' ? :log_title : :name
    @workshop_list    = Workshop.where(inactive: false,
                                       windows_type_id: params[:windows_type_id])

    if @workshop
      log_params = wsl_params.merge(owner_id: @workshop.id)
    else
      log_params = wsl_params
    end

    @workshop_log = WorkshopLog.new( log_params )
    @workshop_log.quotes.build( quotes_params )
    @workshop_log.report_form_field_answers.build( log_fields )
    @workshop_log.media_files.build( files_params )

    if @workshop_log.save
      flash[:alert] = 'Thank you for submitting a workshop log. To see all of your completed logs, please click on “Workshop Log Summary” in the side menu.'
      redirect_to new_workshop_log_path
    end
  end

  def show
    @workshop_log = Report.find(params[:id]).decorate
    @workshop     = @workshop_log.owner.decorate
    @answers      = @workshop_log.report_form_field_answers

    if @workshop_log
      if @workshop_log.project && current_user.project_ids.include?(@workshop_log.project.id)
        render :show
      else
        redirect_to root_path, error: 'You do not have permission to view this page.'
      end
    else
      redirect_to root_path, error: 'Unable to find that Workshop Log.'
    end
  end

  def edit
    @sectors = Sector.published.map{ |si| [ si.id, si.name ] }
    @wl = WorkshopLog.find(params[:id])
    @files = MediaFile.where(["workshop_log_id = ?", @wl.id])
    @agency_title = :name
    @agencies = current_user.projects.uniq

    @workshop = @wl.owner || Workshop.new(windows_type_id: @wl.windows_type_id)
  end


  def validate_new
    @date         = Date.new( params[:year].to_i, params[:month].to_i )
    @windows_type = WindowsType.find(params[:windows_type])
    @report       = current_user.submitted_monthly_report( @date, @windows_type, params[:project_id] )

    render json: { :validate => @report.nil? }.to_json
  end

  private

  def set_default_values
    workshop_log = params[:workshop_log];
    workshop_log.map do |k, v|
      if k.include?('_ongoing') || k.include?('_first_time')
        workshop_log[k] = 0 if v.nil? || v.blank?
      end
    end
  end
  def log_fields
    log_fields_params.map do |k, v|
      { :form_field_id => k, :answer => v, :report_id => @workshop_log.id }
    end
  end

  def log_fields_params
    params.require(:log_fields)
  end

  def ws_params
    params.require(:workshop).permit( sectorable_items: [ :sector_id ] )
  end

  def wsl_params
    params.require(:workshop_log).permit(:children_ongoing, :children_first_time, :teens_ongoing, :teens_first_time, :adults_ongoing, :adults_first_time, :owner_id, :project_id, :date, :workshop_name, :windows_type_id, :other_description, report_form_field_answers: [:form_field_id, :answer_option_id, :answer]).
        merge( :user_id => current_user.id, :owner_type => "Workshop" )
  end

  def quotes_params
    return [] if params[:quotes].nil?
    params[:quotes].permit!.map{|k, v| v}
  end
  def files_params
    return [] if params[:files].nil?
    params[:files].permit!.map{ |k, v| {:file => v} }
  end
end
