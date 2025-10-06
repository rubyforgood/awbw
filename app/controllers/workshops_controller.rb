# frozen_string_literal: true

class WorkshopsController < ApplicationController

  def index
    workshop_ids = Workshop.search_and_sort(params, super_user: current_user.super_user?)
                           .pluck(:id)
    @workshops = Workshop
                   .where(id: workshop_ids)
                   .order(Arel.sql("FIELD(id, #{workshop_ids.join(',')})"))
                   .includes(:categories, :sectors, :windows_type, :user, :images,
                             :workshop_age_ranges, :bookmarks)
                   .paginate(page: params[:page], per_page: params[:per_page] || 50)

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
    @workshop = Workshop.new(user: current_user)
    set_form_variables
  end

  def share_idea
    @workshop = current_user.workshops.build
    set_form_variables
  end

  def edit
    @workshop = Workshop.find(params[:id])
    set_form_variables
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
      flash[:notice] = 'Workshop updated successfully.'
      redirect_to workshops_path
    else
      set_form_variables
      flash[:alert] = 'Unable to update the workshop.'
      render :edit
    end
  end

  def create_workshop_idea
    @workshop = current_user.workshops.build(workshop_params)

    @workshop.inactive = true # Workshop ideas are workshops with inactive == true

    if @workshop.save
      flash[:notice] = 'Thank you for submitting your workshop idea.'
      redirect_to authenticated_root_path
    else
      flash[:alert] = 'Unable to save your workshop idea.'
      render :share_idea
    end
  end

  def create
    @workshop = current_user.workshops.build(workshop_params)

    if @workshop.save
      flash[:notice] = 'Workshop created successfully.'
      redirect_to workshops_path(sort: "created")
    else
      set_form_variables
      flash.now[:alert] = 'Unable to save the workshop.'
      render :new
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
    @quotes = Quote.where(workshop_id: @workshop.id).active
    @leader_spotlights = @workshop.resources.published.leader_spotlights
    @workshop_variations = @workshop.workshop_variations.active
    @sectors = @workshop.sectorable_items.where(inactive: false).map { |item| item.sector if item.sector.published }.compact if @workshop.sectorable_items.any?
  end

  def set_form_variables
    @potential_series_workshops = Workshop.published.where.not(id: @workshop.id).order(:title)
    image = @workshop.images.first || @workshop.images.build # build an image if there isn't one
  end

  def workshops_per_page
    view_all_workshops? ? @workshops.where(inactive: false).count : 12
  end

  def view_all_workshops?
    params[:search][:view_all] == '1'
  end

  def workshop_params
    params.require(:workshop).permit(
      :title, :full_name, :objective, :featured,
      :materials, :optional_materials, :time_hours, :time_minutes, :age_range, :setup,
      :introduction, :demonstration, :opening_circle, :warm_up,
      :visualization, :creation, :closing, :notes, :tips, :misc1, :misc2,
      :windows_type_id, :inactive, :month, :year, :extra_field, :user_id,
      :time_demonstration, :time_warm_up, :time_creation, :time_closing, :objective_spanish,
      :materials_spanish, :optional_materials_spanish, :timeframe_spanish, :age_range_spanish,
      :setup_spanish, :introduction_spanish, :demonstration_spanish, :opening_circle_spanish, :warm_up_spanish,
      :visualization_spanish, :creation_spanish, :closing_spanish, :notes_spanish, :tips_spanish,
      :misc1_spanish, :misc2_spanish, :extra_field_spanish,

      workshop_series_children_attributes: [:id, :workshop_child_id, :workshop_parent_id,
                                            :series_description, :series_description_spanish,
                                            :series_order, :_destroy],
      images_attributes: %i[file owner_id owner_type id _destroy]
    )
  end

  def load_sortable_fields
    @sortable_fields = WindowsType.where('name NOT LIKE ?', '%COMBINED%')
  end

  def load_metadata
    @metadata = Metadatum.published.includes(:categories).decorate
    @sectors = Sector.published
    @windows_types = WindowsType.all
  end
end
