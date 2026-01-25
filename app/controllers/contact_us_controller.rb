class ContactUsController < ApplicationController
  def index
    authorize! :index, with: ContactUsPolicy
  end

  def create
    authorize! :create, with: ContactUsPolicy
    ContactUsMailer.hello(params[:contact_us]).deliver_now
    flash[:notice] = "Your message was sent!"
    redirect_to "/"
  end
end
