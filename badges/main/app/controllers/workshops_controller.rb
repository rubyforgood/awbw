# frozen_string_literal: true

class WorkshopsController < ApplicationController
  def index
    @category_types = CategoryType.includes(:categories).published.decorate
    @sectors = Sector.published
    @windows_types = WindowsType.all
    if turbo_frame_request?
      search_service = WorkshopSearchService.new(params,
        super_user: current_user.super_user?).call
      @sort = search_service.sort

      @workshops = search_service.workshops
        .includes(:categories, :sectors, :windows_type, :user, :images, :bookmarks)
        .paginate(page: params[:page], per_page: params[:per_page] || 50)

      @workshops_count = search_service.workshops.size

      render :workshop_results
    else
      render :index
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

    combined_windows_type = WindowsType.where(short_name: "COMBINED").first
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

    if turbo_frame_request?
      render :rich_text_assets
    else
      render :edit
    end
  end

  def show
    if turbo_frame_request?
      @workshop = Workshop.with_all_rich_text.find(params[:id]).decorate
      set_show
      render partial: "show_lazy", locals: { workshop: @workshop }
    else
      @workshop = Workshop.find(params[:id]).decorate
      @workshop.increment_view_count!(session: session, request: request)
      render :show
    end
  end

  def update
    @workshop = Workshop.find(params[:id])

    # Convert checkbox values into categorizable_items updates
    selected_category_ids = Array(params[:workshop][:category_ids]).reject(&:blank?).map(&:to_i)
    @workshop.categories = Category.where(id: selected_category_ids)

    # Convert checkbox values into sectorable_items updates
    selected_sector_ids = Array(params[:workshop][:sector_ids]).reject(&:blank?).map(&:to_i)
    @workshop.sectors = Sector.where(id: selected_sector_ids)

    if @workshop.update(workshop_params)
      flash[:notice] = "Workshop updated successfully."
      redirect_to workshops_path
    else
      set_form_variables
      flash[:alert] = "Unable to update the workshop."
      render :edit
    end
  end

  def create
    @workshop = current_user.workshops.build(workshop_params)

    # Convert checkbox values into categorizable_items updates
    selected_category_ids = Array(params[:workshop][:category_ids]).reject(&:blank?).map(&:to_i)
    @workshop.categories = Category.where(id: selected_category_ids)

    # Convert checkbox values into sectorable_items updates
    selected_sector_ids = Array(params[:workshop][:sector_ids]).reject(&:blank?).map(&:to_i)
    @workshop.sectors = Sector.where(id: selected_sector_ids)

    if @workshop.save
      flash[:notice] = "Workshop created successfully."
      redirect_to workshops_path(sort: "created")
    else
      set_form_variables
      flash.now[:alert] = "Unable to save the workshop."
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
    @quotes = Quote.where(workshop_id: @workshop.id).active
    @leader_spotlights = @workshop.associated_resources.leader_spotlights.where(inactive: false)
    @workshop_variations = @workshop.workshop_variations.active
    @sectors = @workshop.sectorable_items.published.map { |item| item.sector if item.sector.published }.compact if @workshop.sectorable_items.any?
  end


  def set_form_variables
    @workshop.build_primary_asset if @workshop.primary_asset.blank?
    @workshop.gallery_assets.build

    @age_ranges = Category.includes(:category_type).where("metadata.name = 'AgeRange'").pluck(:name)
    @potential_series_workshops = Workshop.published.where.not(id: @workshop.id).order(:title)
    @windows_types = WindowsType.all
    @workshop_ideas = WorkshopIdea.order(created_at: :desc)
                                  .map { |wi|
                                    [ "#{wi.created_at.strftime("%Y-%m-%d")
                                    } - (#{wi.created_by.full_name}): #{wi.title}", wi.id ] }
    @categories_grouped =
      Category
        .includes(:category_type)
        .published
        .order(:name)
        .group_by(&:category_type)
        .select { |type, _| type.nil? || type.published? }
        .sort_by { |type, _| type&.name.to_s.downcase }

    @sectors = Sector.published.order(:name)
  end

  def workshops_per_page
    view_all_workshops? ? @workshops.published.size : 12
  end

  def view_all_workshops?
    params[:search][:view_all] == "1"
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

      :rhino_objective,
      :rhino_materials,
      :rhino_optional_materials,
      :rhino_setup,
      :rhino_introduction,
      :rhino_opening_circle,
      :rhino_demonstration,
      :rhino_warm_up,
      :rhino_visualization,
      :rhino_creation,
      :rhino_closing,
      :rhino_notes,
      :rhino_tips,
      :rhino_misc1,
      :rhino_misc2,
      :rhino_extra_field,

      :rhino_objective_spanish,
      :rhino_materials_spanish,
      :rhino_optional_materials_spanish,
      :rhino_age_range_spanish,
      :rhino_setup_spanish,
      :rhino_introduction_spanish,
      :rhino_opening_circle_spanish,
      :rhino_demonstration_spanish,
      :rhino_warm_up_spanish,
      :rhino_visualization_spanish,
      :rhino_creation_spanish,
      :rhino_closing_spanish,
      :rhino_notes_spanish,
      :rhino_tips_spanish,
      :rhino_misc1_spanish,
      :rhino_misc2_spanish,
      :rhino_extra_field_spanish,

      category_ids: [],
      sector_ids: [],
      primary_asset_attributes: [ :id, :file, :_destroy ],
      gallery_assets_attributes: [ :id, :file, :_destroy ],
      workshop_series_children_attributes: [ :id, :workshop_child_id, :workshop_parent_id, :theme_name,
                                            :series_description, :series_description_spanish,
                                            :position, :_destroy ],
    )
  end

  def load_sortable_fields
    @sortable_fields = WindowsType.where(short_name: "COMBINED")
  end

  def load_metadata
    @metadata = CategoryType.includes(:categories).published.decorate
  end
end
