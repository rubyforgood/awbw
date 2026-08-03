class TrainingInterestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_training_interest, only: [ :edit, :update, :destroy ]

  def index
    authorize! TrainingInterest
    @training_interests = TrainingInterest
      .search_by_params(params)
      .includes(:event, person: { event_registrations: :event })
      .newest_first
      .paginate(page: params[:page], per_page: 25)
    render :training_interests_results if turbo_frame_request?
  end

  def new
    authorize! TrainingInterest
    @training_interest = TrainingInterest.new(status: "open", event_id: params[:event_id])
  end

  def create
    authorize! TrainingInterest
    @training_interest = TrainingInterest.new(training_interest_params)
    @training_interest.created_by = current_user
    @training_interest.updated_by = current_user

    if @training_interest.save
      redirect_to training_interests_path, notice: "Interest recorded."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! @training_interest
  end

  def update
    authorize! @training_interest
    @training_interest.updated_by = current_user

    if @training_interest.update(training_interest_params)
      redirect_to training_interests_path, notice: "Interest updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @training_interest
    @training_interest.destroy
    redirect_to training_interests_path, notice: "Interest removed."
  end

  private

  def set_training_interest
    @training_interest = TrainingInterest.find(params[:id])
  end

  def training_interest_params
    params.require(:training_interest).permit(:person_id, :event_id, :status, :source, :note, :expressed_at)
  end
end
