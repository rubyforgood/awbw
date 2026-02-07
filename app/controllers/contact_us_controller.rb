class ContactUsController < ApplicationController
  def index
    authorize! :contact_us, to: :index?
  end

  def create
    authorize! :contact_us, to: :create?
    ContactUsMailer.hello(params[:contact_us]).deliver_now
    flash[:notice] = "Your message was sent!"
    redirect_to "/"
  end
end
