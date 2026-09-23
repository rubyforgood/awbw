class InvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_invoice, only: [ :show, :edit, :update, :destroy ]

  def index
    @invoices = Invoice.all.order(date: :desc)
    authorize! Invoice, to: :index?
  end

  def new
    @invoice = Invoice.new(number: Invoice.next_number)
    authorize! @invoice
    @invoice.invoice_line_items.build
  end

  def create
    @invoice = Invoice.new(invoice_params)
    authorize! @invoice

    if @invoice.save
      redirect_to invoice_path(@invoice), notice: "Invoice created."
    else
      flash.now[:alert] = error_sentence(@invoice)
      @invoice.invoice_line_items.build if @invoice.invoice_line_items.empty?
      render :new
    end
  end

  def show
    @presenter = InvoicePresenter.new(@invoice)
    authorize! @invoice
  end

  def edit
    authorize! @invoice
    @invoice.invoice_line_items.build if @invoice.invoice_line_items.empty?
  end

  def update
    authorize! @invoice

    if @invoice.update(invoice_params)
      redirect_to invoice_path(@invoice), notice: "Invoice updated."
    else
      flash.now[:alert] = error_sentence(@invoice)
      @invoice.invoice_line_items.build if @invoice.invoice_line_items.empty?
      render :edit
    end
  end

  def destroy
    authorize! @invoice
    @invoice.destroy
    redirect_to invoices_path, notice: "Invoice deleted."
  end

  private

  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(
      :number, :date, :client_sgid, :bill_to_address,
      :attention_person_id,
      invoice_line_items_attributes: [ :id, :date, :description, :quantity, :unit_price_cents, :_destroy ]
    )
  end
end
