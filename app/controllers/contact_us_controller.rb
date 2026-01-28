class ContactUsController < ApplicationController
  def index
    authorize!
  end

  def create
    authorize!
    ContactUsMailer.hello(params[:contact_us]).deliver_now
    flash[:notice] = "Your message was sent!"
    redirect_to "/"
  end
end
