class WorkshopLogsController < ApplicationController
  before_action :set_workshop, only: [:index]

  def index
    # If @workshop is present, set params[:workshop_id] so search handles it
    params[:workshop_id] ||= @workshop&.id
    @workshop_logs_unpaginated = WorkshopLog.includes(:workshop, :user, :windows_type)
                                            .search(params)
    @workshop_logs = @workshop_logs_unpaginated.paginate(page: params[:page], per_page: 25)
    set_index_variables
  end

  def new
    @workshop_log = WorkshopLog.new
    set_form_variables
  end

  def update
    set_default_values
    @workshop_log = WorkshopLog.find params[:id]

    ActiveRecord::Base.transaction do
      @workshop_log.update(workshop_log_params)
      @saved = @workshop_log.delete_and_update_all(params[:quotes_attributes], params[:report_form_field_answers_attributes])
    end

    if @saved
      # TODO - why are we iterating over files params after the fact?
      params[:files].each do |file|
        file = MediaFile.new(file: file)
        file.update(report_id: @workshop_log.id, owner_type: @workshop_log.owner_type, owner_id: @workshop_log.owner_id)
        file.save
      end
      flash[:notice] = 'Thanks for reporting on a workshop.'
      redirect_to authenticated_root_path
    else
      set_form_variables
      render :edit
    end
  end

  def create
    set_default_values
    @workshop_log = WorkshopLog.new(workshop_log_params)

    if @workshop_log.save
      flash[:notice] = 'Thank you for submitting a workshop log. To see all of your completed logs, please view your Profile.'
      redirect_to authenticated_root_path
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def show
    @workshop_log = Report.find(params[:id]).decorate
    @workshop     = @workshop_log.owner.decorate
    @answers      = @workshop_log.report_form_field_answers

    if @workshop_log
      if current_user.super_user? || (@workshop_log.project && current_user.project_ids.include?(@workshop_log.project.id))
        render :show
      else
        redirect_to authenticated_root_path, error: 'You do not have permission to view this page.'
      end
    else
      redirect_to authenticated_root_path, error: 'Unable to find that Workshop Log.'
    end
  end

  def edit
    @workshop_log = WorkshopLog.find(params[:id])
    @workshop = @workshop_log.owner || Workshop.new(windows_type_id: @workshop_log.windows_type_id)

    set_form_variables
  end


  def validate_new
    @date         = Date.new( params[:year].to_i, params[:month].to_i )
    @windows_type = WindowsType.find(params[:windows_type])
    @report       = current_user.submitted_monthly_report( @date, @windows_type, params[:project_id] )

    render json: { :validate => @report.nil? }.to_json
  end

  private

  def set_form_variables
    if params[:workshop_id]
      @workshop = Workshop.where(id: params[:workshop_id]).last
    elsif params[:windows_type_id]
      @workshop = Workshop.new(windows_type_id: params[:windows_type_id])
    else
      @workshop = Workshop.new
    end

    @workshops = current_user.curriculum(Workshop)
                             .where(inactive: false)
                             .order(title: :asc)

    # Build one blank quote if none exists
    @workshop_log.quotable_item_quotes.each do |qiq|
      qiq.build_quote unless qiq.quote
      qiq.quotable = @workshop_log
    end

    # Always build at least one new blank quotable_item_quote
    if @workshop_log.quotable_item_quotes.empty?
      qiq = @workshop_log.quotable_item_quotes.build
      qiq.build_quote
      qiq.quotable = @workshop_log
    end

    # Pre-build a file upload for the form
    @workshop_log.media_files.build if @workshop_log.media_files.empty?

    # @sectors = Sector.published.map{ |si| [ si.id, si.name ] }
    # @files = MediaFile.where(["workshop_log_id = ?", @workshop_log.id])

    @windows_type_id = params[:windows_type_id].presence || @workshop.windows_type_id || 3
    form = FormBuilder.where(windows_type_id: @windows_type_id)
                      .first&.forms.first # because there's only one form per form_builder
    if form
      @report_field_answers = form.form_fields.active.order(:ordering).map do |field|
        @workshop_log.report_form_field_answers.find_or_initialize_by(form_field: field)
      end
    end

    @title = params[:windows_type_id] == '3' ? :log_title : :title
    @agency_title = params[:windows_type_id] == '3' ? :log_title : :name

    @agencies = current_user.projects.uniq
    agency = params[:agency_id].present? ? Project.where(id: params[:agency_id]).last : @agencies.first
    @agency_id = agency.id if agency
  end

  def set_default_values
    workshop_log = params[:workshop_log];
    workshop_log.to_unsafe_h.map do |k, v|
      if k.include?('_ongoing') || k.include?('_first_time')
        workshop_log[k] = 0 if v.nil? || v.blank?
      end
    end
  end

  def set_index_variables
    @month_year_options = WorkshopLog.where.not(date: nil)
                                     .group("DATE_FORMAT(COALESCE(date, created_at), '%Y-%m')")
                                     .select("DATE_FORMAT(COALESCE(date, created_at), '%Y-%m') AS ym, MAX(COALESCE(date, created_at)) AS max_dt")
                                     .order("max_dt DESC")
                                     .map { |record| [Date.strptime(record.ym, "%Y-%m").strftime("%B %Y"), record.ym] }
    @year_options = WorkshopLog.pluck(Arel.sql("DISTINCT EXTRACT(YEAR FROM COALESCE(date, created_at))"))
                               .sort
                               .reverse
    @facilitators = User.joins(:workshop_logs)
                        .distinct
                        .order(:last_name, :first_name)
    # @workshops = Workshop.joins(:workshop_logs)
    #                      .order(:title)
  end

  def set_workshop
    @workshop = Workshop.find_by(id: params[:workshop_id])
  end

  # def ws_params # TODO - figure out why this was needed in 2016
  #   params.require(:workshop).permit( sectorable_items: [ :sector_id ] )
  # end

  def workshop_log_params
    params.require(:workshop_log).permit(
      :children_ongoing, :children_first_time, :teens_ongoing, :teens_first_time,
      :adults_ongoing, :adults_first_time, :owner_id,:owner_type, :user_id, :project_id, :date,
      :workshop_name, :workshop_id, :windows_type_id, :other_description, #:user,
      quotable_item_quotes_attributes: [
        :id, :quotable_type, :quotable_id, :_destroy,
        quote_attributes: [:id, :quote, :age, :workshop_id, :_destroy]],
      media_files_attributes: [:id, :file, :_destroy],
      report_form_field_answers_attributes: [:id, :form_field_id, :answer_option_id,
                                             :answer, :report_id, :_destroy])
  end
end
