class InvoicesController < ApplicationController
  before_action :set_invoice, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize! Invoice
    @invoices = Invoice.all.order(date: :desc)
  end

  def new
    authorize! Invoice
    @invoice = Invoice.new(number: Invoice.next_number)
    @invoice.invoice_line_items.build
  end

  def create
    authorize! Invoice
    @invoice = Invoice.new(invoice_params)

    if @invoice.save
      redirect_to invoice_path(@invoice), notice: "Invoice created."
    else
      flash.now[:alert] = @invoice.errors.full_messages.join(", ")
      @invoice.invoice_line_items.build if @invoice.invoice_line_items.empty?
      render :new, status: :unprocessable_content
    end
  end

  def show
    @presenter = InvoicePresenter.new(@invoice)
  end

  def edit
    @invoice.invoice_line_items.build if @invoice.invoice_line_items.empty?
  end

  def update
    if @invoice.update(invoice_params)
      redirect_to invoice_path(@invoice), notice: "Invoice updated."
    else
      flash.now[:alert] = @invoice.errors.full_messages.join(", ")
      @invoice.invoice_line_items.build if @invoice.invoice_line_items.empty?
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @invoice.destroy
    redirect_to invoices_path, notice: "Invoice deleted."
  end

  private

  def set_invoice
    @invoice = Invoice.find(params[:id])
    authorize! @invoice
  end

  def invoice_params
    params.require(:invoice).permit(
      :number, :date, :invoicee_sgid, :bill_to_address_id, :bill_to_additional_info,
      :hide_invoicee, :hide_address,
      :attention_person_id,
      invoice_line_items_attributes: [ :id, :date, :description, :quantity, :unit_price_cents, :unit_price_dollars, :_destroy ]
    )
  end
end
