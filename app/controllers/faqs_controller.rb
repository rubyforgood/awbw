class FaqsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_faq, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    faqs = authorized_scope(Faq.all)
    @faqs = faqs.search_by_params(params.to_unsafe_h.slice("query", "published"))
              .by_position
              .page(params[:page])
  end

  def show
    authorize! @faq
  end

  def new
    @faq = Faq.new
    authorize! @faq
    set_form_variables
  end

  def edit
    authorize! @faq
    set_form_variables
  end

  def create
    @faq = Faq.new(faq_params)
    authorize! @faq

    if @faq.save
      redirect_to @faq, notice: "FAQ was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @faq
    notice = "FAQ was successfully updated."
    flash.now[:notice] = notice
    if @faq.update(faq_params)
      redirect_to @faq, notice: notice, status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @faq
    @faq.destroy!
    redirect_to faqs_path, notice: "FAQ was successfully destroyed."
  end

  # Optional hooks for setting variables for forms or index
  def set_form_variables
  end

  private

  def set_faq
    @faq = Faq.find(params[:id])
  end

  # Strong parameters
  def faq_params
    params.require(:faq).permit(:question, :answer, :position, :published, :publicly_visible)
  end
end
