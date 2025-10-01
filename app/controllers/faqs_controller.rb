class FaqsController < ApplicationController
  before_action :set_faq, only: [:show, :edit, :update, :destroy]

  layout "tailwind", only: [:index]

  def index
    @faqs = if current_user.super_user?
      Faq.by_order
    else
      Faq.active.by_order
    end
  end

  def show
  end

  def new
    @faq = Faq.new
    set_form_variables
  end

  def edit
    set_form_variables
  end

  def create
    @faq = Faq.new(faq_params)

    if @faq.save
      redirect_to faqs_path, notice: "FAQ was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @faq.update(faq_params)
      redirect_to faqs_path, notice: "FAQ was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
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
    params.require(:faq).permit(:question, :answer, :inactive, :ordering)
  end
end
