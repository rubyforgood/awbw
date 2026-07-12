class PaymentsController < ApplicationController
  # authorize! calls use with: PaymentPolicy explicitly because @payment uses STI
  # (CashPayment, CheckPayment, ExternalProcessorPayment), and ActionPolicy would
  # otherwise look up a policy by the subclass name (e.g. ExternalProcessorPaymentPolicy).
  PERMITTED_PAYMENT_TYPES = %w[CashPayment CheckPayment ExternalProcessorPayment].freeze
  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 10

    if turbo_frame_request?
      @payments = Payment.search_by_params(params).order(created_at: :desc).paginate(page: params[:page], per_page: per_page)
      render :payments_results
    else
      @payments = Payment.search_by_params(params).order(created_at: :desc).paginate(page: params[:page], per_page: per_page)
    end
  end

  def new
    authorize!
    payment_type = params[:type]
    unless PERMITTED_PAYMENT_TYPES.include?(payment_type)
      redirect_to payments_path, alert: "Invalid payment type" and return
    end
    @payment = permitted_payment_type(payment_type).new

    if params[:allocatable_sgid].present?
      @allocatable = GlobalID::Locator.locate_signed(params[:allocatable_sgid])
      person, organization = registrant_and_organization_for(@allocatable)
      @payment.person = person
      @payment.organization = organization
    end
  end

  def create
    authorize!
    payment_class = permitted_payment_type(params[:payment][:type])

    unless payment_class
      @payment = Payment.new(payment_params.except(:allocatable_sgid, :type))
      @payment.errors.add(:type, "is not a valid payment type")
      render :new, status: :unprocessable_content and return
    end

    allocatable = locate_allocatable

    begin
      if allocatable.present?
        payment_attrs = build_payment_attributes(payment_params, allocatable)
        @payment = payment_class.new(payment_attrs)

        process_allocation!(@payment, allocatable)

        flash[:notice] = "Allocation created. #{helpers.dollars_from_cents(@payment.reload.amount_cents_remaining)} remaining on payment."
        redirect_path = allocations_path(allocatable_sgid: allocatable.to_sgid.to_s)
      else
        @payment = payment_class.new(payment_params.except(:allocatable_sgid, :type))
        @payment.save!
        redirect_path = payments_path
      end

      respond_to do |format|
        format.turbo_stream { redirect_to redirect_path }
        format.html { redirect_to redirect_path, notice: "Payment was successfully created." }
      end

    rescue ActiveRecord::RecordInvalid => e
      if allocatable.present?
        @allocatable = allocatable
        flash.now[:error] = @payment.errors.full_messages.join(", ")
        respond_to do |format|
          format.turbo_stream { render status: :unprocessable_content }
          format.html { render :new, status: :unprocessable_content }
        end
      else
        flash[:error] = @payment.errors.full_messages.join(", ")
        render :new, status: :unprocessable_content
      end
    end
  end

  def show
    @payment = Payment.find(params[:id])
    @allocations = @payment.allocations.order(created_at: :desc)
    @refunds = @payment.refunds.order(created_at: :desc)
    authorize! @payment, with: PaymentPolicy
  end

  def edit
    @payment = Payment.find(params[:id])
    authorize! @payment, with: PaymentPolicy
  end

  def update
    @payment = Payment.find(params[:id])
    authorize! @payment, with: PaymentPolicy

    if @payment.update(edit_payment_params)
      redirect_to payment_path(@payment), notice: "Payment was successfully updated."
    else
      flash.now[:alert] = @payment.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_content
    end
  end

  def new_checkout_link
    authorize!
  end

  def create_checkout_link
    authorize!
    amount_cents = (params[:amount_dollars].to_d * 100).to_i

    if amount_cents <= 0
      flash.now[:alert] = "Amount must be greater than $0.00"
      render :new_checkout_link, status: :unprocessable_content
      return
    end

    description = params[:description].presence || "Custom Stripe Payment"

    checkout_session = Stripe::Checkout::Session.create(
      mode: "payment",
      line_items: [ {
        price_data: {
          currency: "usd",
          product_data: { name: description },
          unit_amount: amount_cents
        },
        quantity: 1
      } ],
      payment_intent_data: {
        description: description
      },
      custom_fields: [
        {
          key: "first_name",
          label: { type: "custom", custom: "First name" },
          type: "text",
          optional: false
        },
        {
          key: "last_name",
          label: { type: "custom", custom: "Last name" },
          type: "text",
          optional: false
        },
        {
          key: "organization",
          label: { type: "custom", custom: "Organization" },
          type: "text",
          optional: true
        }
      ],
      success_url: root_url,
      cancel_url: root_url
    )

    @checkout_url = checkout_session.url
    render :new_checkout_link
  end

  def allocation_form
    authorize!
    payment_type = params[:type].presence
    unless PERMITTED_PAYMENT_TYPES.include?(payment_type)
      head :unprocessable_content and return
    end
    @payment = permitted_payment_type(payment_type).new

    if params[:allocatable_sgid].present?
      @allocatable = GlobalID::Locator.locate_signed(params[:allocatable_sgid])
      person, organization = registrant_and_organization_for(@allocatable)
      @payment.person = person
      @payment.organization = organization
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def permitted_payment_type(type)
    return nil unless type.present? && PERMITTED_PAYMENT_TYPES.include?(type)
    type.constantize
  end

  def payment_params
    params.require(:payment).permit(:type, :payer_type, :person_id, :organization_id, :payer_sgid, :additional_designation_sgid, :amount_dollars, :currency, :check_number, :memo, :allocatable_sgid)
  end

  def locate_allocatable
    return nil unless params[:payment][:allocatable_sgid].present?
    GlobalID::Locator.locate_signed(params[:payment][:allocatable_sgid])
  end

  def registrant_and_organization_for(allocatable)
    case allocatable
    when EventRegistration
      [ allocatable.registrant, allocatable.organizations.first ]
    when ContinuingEducationRegistration
      [ allocatable.event_registration.registrant, allocatable.event_registration.organizations.first ]
    else
      [ nil, nil ]
    end
  end

  def build_payment_attributes(payment_params, allocatable)
    attrs = payment_params.except(:allocatable_sgid, :type)
    person, = registrant_and_organization_for(allocatable)
    attrs[:person_id] ||= person&.id
    attrs
  end

  def process_allocation!(payment, allocatable)
    Payment.transaction do
      payment.save!

      payment.with_lock do
        allocation_amount = calculate_allocation_amount(payment, allocatable)
        current_allocated = payment.allocations.sum(:amount)

        if current_allocated + allocation_amount > payment.amount_cents
          raise ActiveRecord::Rollback, "Cannot allocate more than payment amount"
        end

        Allocation.create!(
          source: payment,
          allocatable: allocatable,
          amount: allocation_amount
        )

        payment.update!(amount_cents_remaining: payment.amount_cents - current_allocated - allocation_amount)
      end
    end
  end

  def calculate_allocation_amount(payment, allocatable)
    cost_cents = allocatable.cost_cents

    if cost_cents.blank? || cost_cents <= 0
      payment.errors.add(:base, "Cannot allocate to a free registration.")
      raise ActiveRecord::RecordInvalid.new(payment)
    end

    remaining_needed = cost_cents - allocatable.allocations_sum

    if remaining_needed <= 0
      payment.errors.add(:base, "Registration is already fully paid.")
      raise ActiveRecord::RecordInvalid.new(payment)
    end

    [ payment.amount_cents, remaining_needed ].min
  end

  def edit_payment_params
    params.require(:payment).permit(:person_id, :organization_id, :form_submission_id, :payer_sgid, :additional_designation_sgid)
  end

  def redirect_path_for(allocatable)
    allocations_path(allocatable_sgid: allocatable.to_sgid.to_s)
  end
end
