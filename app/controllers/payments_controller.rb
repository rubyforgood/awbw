class PaymentsController < ApplicationController
  before_action :set_payment, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 25
    base_scope = authorized_scope(Payment.all)
    filtered = base_scope.search_by_params(params)
    @payments_count = filtered.count
    @payments = filtered
      .includes(:payer, :organization, event_registrations: [ :registrant, :event ])
      .order(created_at: :desc)
      .paginate(page: params[:page], per_page: per_page)
  end

  def show
    authorize! @payment
  end

  def new
    @payment = Payment.new
    authorize! @payment
    set_form_variables
  end

  def edit
    authorize! @payment
    set_form_variables
  end

  def create
    @payment = Payment.new(payment_params)
    authorize! @payment

    if @payment.save
      redirect_to @payment, notice: "Payment was successfully created."
    else
      set_form_variables
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! @payment

    if @payment.update(payment_params)
      redirect_to @payment, notice: "Payment was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @payment
    if @payment.destroy
      flash[:notice] = "Payment was successfully deleted."
    else
      flash[:alert] = @payment.errors.full_messages.to_sentence
    end
    redirect_to payments_path
  end

  def set_form_variables
  end

  private

  def set_payment
    @payment = Payment.find(params[:id])
  end

  def payment_params
    params.require(:payment).permit(
      :amount_cents, :currency, :status, :payment_type,
      :stripe_payment_intent_id, :stripe_charge_id,
      :payer_id, :event_id, :organization_id,
      :failure_code, :failure_message,
      event_registration_ids: []
    )
  end
end
