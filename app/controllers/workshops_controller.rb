# frozen_string_literal: true

class WorkshopsController < ApplicationController
  def index
    @workshops = current_user.curriculum(Workshop).search(params).paginate(page: params[:page], per_page: 20)

    load_sortable_fields
    load_metadata

    respond_to do |format|
      format.html
    end
  end

  def summary
    @year = params[:year] ? params[:year].to_i : Date.current.year.to_i
    @month = params[:month] ? params[:month].to_i : Date.current.month.to_i

    reports = build_report
    @report = reports[0]

    types = reports.map do |r|
      r.windows_type
    end
    @workshop_logs = current_user.project_monthly_workshop_logs(
      reports.first.date, *types,
    )

    logs = @workshop_logs.map { |_k, v| v }.flatten
    @total_ongoing    = logs.reduce(0) { |sum, l| sum += l.num_ongoing }
    @total_first_time = logs.reduce(0) { |sum, l| sum += l.num_first_time }

    combined_windows_type = WindowsType.where("name LIKE ?", "%COMBINED (FAMILY)%").first
    @combined_workshop_logs = current_user.project_workshop_logs(
      @report.date, combined_windows_type, current_user.agency_id
    )
  end

  def build_report
    date = Date.new(@year, @month)

    form_builder = FormBuilder
                   .monthly

    report = form_builder.map do |f|
      Report.new(
        type: f.report_type,
        windows_type: f.windows_type,
        date: date
      )
    end

    report.each do |r|
      r.media_files.build
    end

    report
  end

  def new
    @workshop = current_user.workshops.build
    @image    = @workshop.images.build
  end

  def share_idea
    @workshop = current_user.workshops.build
    @image    = @workshop.images.build
  end

  def edit
    @workshop = Workshop.find(params[:id])
    @image    = @workshop.images.build if @workshop.images.empty?
  end

  def show
    set_show
  end

  def share_idea_show
    set_show
  end

  def update
    @workshop = Workshop.find(params[:id])
    if @workshop.update(workshop_params)
      flash[:alert] = 'Thank you for sharing your workshop idea.'
      redirect_to root_path
    else
      flash[:error] = 'Unable to update the workshop.'
      render :edit
    end
  end

  def create_from_log
    @workshop = current_user.workshops.build(workshop_params)

    if @workshop.save
      flash[:alert] = 'Workshop created succesfully.'
      redirect_to "/workshop_logs/new?windows_type_id=#{@workshop.windows_type.id}&workshop_id=#{@workshop.id}"
    else
      flash[:error] = 'Unable to save the workshop.'
      render :new
    end
  end

  def create
    @workshop = current_user.workshops.build(workshop_params)
    # Only workshop ideas are being created from here
    @workshop.inactive = true

    if @workshop.save
      flash[:alert] = 'Thank you for sharing your workshop idea.'
      redirect_to root_path
    else
      flash[:error] = 'Unable to save the workshop.'
      render :share_idea
    end
  end

  def create_dummy_workshop
    @workshop = current_user.workshops.build(title: params[:title], windows_type_id: params[:windows_type_id], inactive: false)
    if @workshop.save
      render json: { id: @workshop.id }
    else
      render json: { error: @workshop.errors }
    end
  end

  def search
    @params = params[:search]
    @query = params[:search][:query] if @params
    @workshops = Search.new.search(@params, current_user)

    if @workshops.paginate(page: params[:search][:page], per_page: workshops_per_page).empty?
      @workshops = @workshops.paginate(page: 1, per_page: workshops_per_page)
    else
      @workshops = @workshops.paginate(page: params[:search][:page], per_page: workshops_per_page)
    end

    load_sortable_fields
    load_metadata

    render :index
  end

  private

  def set_show
    @workshop = Workshop.find(params[:id]).decorate
    @bookmark = current_user.bookmarks.find_by(bookmarkable: @workshop)
    @new_bookmark = @workshop.bookmarks.build
    @quotes = @workshop.quotes.active
    @leader_spotlights = @workshop.resources.published
    @workshop_variations = @workshop.workshop_variations
    @sectors = @workshop.sectorable_items.where(inactive: false).map { |item| item.sector if item.sector.published }.compact if @workshop.sectorable_items.any?
  end

  def workshops_per_page
    view_all_workshops? ? @workshops.count : 12
  end

  def view_all_workshops?
    params[:search][:view_all] == '1'
  end

  def workshop_params
    params.require(:workshop).permit(
      :title, :full_name, :objective,
      :materials, :optional_materials, :time_hours, :time_minutes, :age_range, :setup,
      :introduction, :demonstration, :opening_circle, :warm_up,
      :visualization, :creation, :closing, :notes, :tips, :misc1, :misc2,
      :windows_type_id, :inactive,
      images_attributes: %i[file owner_id owner_type id _destroy]
    )
  end

  def load_sortable_fields
    @sortable_fields = WindowsType.where('name NOT LIKE ?', '%COMBINED%')
  end

  def load_metadata
    @metadata = Metadatum.published.includes(:categories).decorate
    @sectors = Sector.published
  end
end
