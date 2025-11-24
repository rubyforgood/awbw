# frozen_string_literal: true

class WorkshopsController < ApplicationController

  def index
    search_service = WorkshopSearchService.new(params, super_user: current_user.super_user?).call
    @sort = params[:sort] # search_service.default_sort

    @workshops = search_service.workshops
                               .includes(:categories, :sectors, :windows_type, :user, :images,
                                         :workshop_age_ranges, :bookmarks)
                               .paginate(page: params[:page], per_page: params[:per_page] || 50)

    @workshops_count = search_service.workshops.size

    @category_metadata = Metadatum.published.includes(:categories).decorate
    @sectors = Sector.published
    @windows_types = WindowsType.all

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
    if params[:workshop_idea_id].present?
      @workshop_idea = WorkshopIdea.find(params[:workshop_idea_id])
      @workshop = WorkshopFromIdeaService.new(@workshop_idea, user: current_user).call
    else
      @workshop = Workshop.new(user: current_user)
    end
    set_form_variables
  end

  def edit
    @workshop = Workshop.find(params[:id])
    set_form_variables
  end

  def show
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
    @sectors = @workshop.sectorable_items.published.map { |item| item.sector if item.sector.published }.compact if @workshop.sectorable_items.any?
  end

  def set_form_variables
    @workshop.build_main_image if @workshop.main_image.blank?
    @workshop.gallery_images.build

    @age_ranges = AgeRange.all
    @potential_series_workshops = Workshop.published.where.not(id: @workshop.id).order(:title)
    @windows_types = WindowsType.all
    @workshop_ideas = WorkshopIdea.order(created_at: :desc)
                                  .map { |wi|
                                    ["#{wi.created_at.strftime("%Y-%m-%d")
                                    } - (#{wi.created_by.full_name}): #{wi.title}", wi.id] }
  end

  def workshops_per_page
    view_all_workshops? ? @workshops.published.size : 12
  end

  def view_all_workshops?
    params[:search][:view_all] == '1'
  end

  def workshop_params
    params.require(:workshop).permit(
      :title, :featured, :inactive,
      :full_name, :user_id, :windows_type_id, :workshop_idea_id,
      :month, :year,

      :time_intro, :time_closing, :time_creation, :time_demonstration,
      :time_warm_up, :time_opening, :time_opening_circle,

      :age_range, :age_range_spanish,
      :closing, :closing_spanish,
      :creation, :creation_spanish,
      :demonstration, :demonstration_spanish,
      :extra_field, :extra_field_spanish,
      :introduction, :introduction_spanish,
      :materials, :materials_spanish,
      :misc1, :misc1_spanish,
      :misc2, :misc2_spanish,
      :notes, :notes_spanish,
      :objective, :objective_spanish,
      :opening_circle, :opening_circle_spanish,
      :optional_materials, :optional_materials_spanish,
      :setup, :setup_spanish,
      :tips, :tips_spanish,
      :timeframe_spanish,
      :visualization, :visualization_spanish,
      :warm_up, :warm_up_spanish,

      workshop_series_children_attributes: [:id, :workshop_child_id, :workshop_parent_id, :theme_name,
                                            :series_description, :series_description_spanish,
                                            :series_order, :_destroy],
      main_image_attributes: [:id, :file, :_destroy],
      gallery_images_attributes: [:id, :file, :_destroy]
    )
  end

  def load_sortable_fields
    @sortable_fields = WindowsType.where('name NOT LIKE ?', '%COMBINED%')
  end

  def load_metadata
    @metadata = Metadatum.published.includes(:categories).decorate
  end
end
