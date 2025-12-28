class QuotesController < ApplicationController
  before_action :set_quote, only: [:show, :edit, :update, :destroy]

  def index
    per_page = params[:number_of_items_per_page].presence || 25
    unpaginated = Quote.where.not(quote: [nil, ""])
                       .search_by_params(params)
                       .order(created_at: :desc)
    @quotes_count = unpaginated.count
    @quotes = unpaginated.paginate(page: params[:page], per_page: per_page)
  end

  def show
    @quote.increment_view_count!(session: session, request: request)
  end

  def new
    @quote = Quote.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @quote = Quote.new(quote_params)

    if @quote.save
      redirect_to quotes_path, notice: "Quote was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @quote.update(quote_params)
      redirect_to quotes_path, notice: "Quote was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @quote.destroy!
    redirect_to quotes_path, notice: "Quote was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
    workshops = current_user.super_user? ? Workshop.all : Workshop.active
    @workshops = workshops.order(:title)
  end

  private

  def set_quote
    @quote = Quote.find(params[:id]).decorate
  end

  # Strong parameters
  def quote_params
    params.require(:quote).permit(
      :age,
      :gender,
      :inactive,
      :quote,
      :speaker_name,
      :workshop_id,
    )
  end
end
