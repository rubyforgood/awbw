class QuotesController < ApplicationController
  include AhoyTracking, TagAssignable
  before_action :set_quote, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(Quote.where.not(body: [ nil, "" ]))
    filtered = base_scope.search_by_params(params)
                         .order(created_at: :desc)
    @quotes_count = filtered.count
    @quotes = filtered.paginate(page: params[:page], per_page: per_page)
    @source_type_options = Quote.source_type_options
  end

  def show
    authorize! @quote
    track_view(@quote)
  end

  def new
    @quote = Quote.new
    authorize! @quote
    set_form_variables
  end

  def edit
    authorize! @quote
    set_form_variables
  end

  def create
    @quote = Quote.new(quote_params)
    @quote.created_by = current_user
    authorize! @quote

    success = false
    Quote.transaction do
      if @quote.save
        assign_associations(@quote)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Quote create failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to @quote, notice: "Quote was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @quote
    @quote.updated_by = current_user

    success = false
    Quote.transaction do
      if @quote.update(quote_params)
        assign_associations(@quote)
        success = true
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error "Quote update failed: #{e.class} - #{e.message}"
      raise ActiveRecord::Rollback
    end

    if success
      redirect_to @quote, notice: "Quote was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @quote
    @quote.destroy!
    redirect_to quotes_path, notice: "Quote was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    @workshops = authorized_scope(Workshop.all).order(:title)
    @sectors = Sector.published.order(:name)
    @categories_grouped =
      Category
        .includes(:category_type)
        .published
        .order(:position, :name)
        .group_by(&:category_type)
        .select { |type, _| type.nil? || (type.published? && !type.story_specific? && !type.profile_specific?) }
        .sort_by { |type, _| type&.name.to_s.downcase }
  end

  private

  def set_quote
    @quote = Quote.find(params[:id]).decorate
  end

  # Strong parameters
  def quote_params
    params.require(:quote).permit(
      :age,
      :author_id,
      :body,
      :gender,
      :original_body,
      :published,
      :speaker_name,
      :standout,
      :workshop_id,
    )
  end
end
