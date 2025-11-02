class FacilitatorsController < ApplicationController
  # Skip login requirement for new facilitator form
  # temporarily skipping authentication for all actions for development ease
  #TODO: remove :index & :show from skip_before_action
  if Rails.env.development?
    skip_before_action :authenticate_user!, only: [:index, :show, :update, :edit, :new, :create]
  end

  before_action :set_facilitator, only: %i[ show edit update destroy ]

  def index
    @facilitators = Facilitator.all
  end

  def show
    @facilitator = Facilitator.find(params[:id]).decorate
  end

  def new
    @facilitator = Facilitator.new
  end

  def edit
  end

  def create
    @facilitator = Facilitator.new(facilitator_params)

    respond_to do |format|
      if @facilitator.save
        format.html { redirect_to @facilitator, notice: "Facilitator was successfully created." }
      else
        format.html { render :new, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if @facilitator.update(facilitator_params)
        format.html { redirect_to @facilitator, notice: "Facilitator was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @facilitator.destroy

    respond_to do |format|
      format.html { redirect_to facilitators_path, status: :see_other, notice: "Facilitator was successfully destroyed." }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_facilitator
      @facilitator = Facilitator.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def facilitator_params
      params.require(:facilitator).permit(Facilitator::PERMITTED_PARAMS)
    end
end
