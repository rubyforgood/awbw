class InvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_invoice, only: [ :show, :edit, :update, :destroy ]

  def index
    @invoices = Invoice.all.order(date: :desc)
    authorize! Invoice, to: :index?
  end

  def new
    @invoice = Invoice.new
    authorize! @invoice
    @invoice.invoice_line_items.build
  end

  def create
    @invoice = Invoice.new(invoice_params)
    @invoice.client_type = client_type_from_id(@invoice.client_id)
    authorize! @invoice

    if @invoice.save
      redirect_to invoice_path(@invoice), notice: "Invoice created."
    else
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
    params[:invoice][:client_type] = client_type_from_id(params[:invoice][:client_id])

    if @invoice.update(invoice_params)
      redirect_to invoice_path(@invoice), notice: "Invoice updated."
    else
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
      :number, :date, :client_id, :bill_to_address,
      :attention_person_id, :client_type,
      invoice_line_items_attributes: [ :id, :date, :description, :quantity, :unit_price_cents, :_destroy ]
    )
  end

  def client_type_from_id(client_id)
    return unless client_id.present?
    if Person.exists?(client_id)
      "Person"
    elsif Organization.exists?(client_id)
      "Organization"
    end
  end

  def client_label_data
    return unless @invoice&.client&.persisted?
    { label: @invoice.client.compound_search_label[:label], id: @invoice.client.id }
  rescue
    nil
  end
end
