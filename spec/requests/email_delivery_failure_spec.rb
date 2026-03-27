require "rails_helper"

RSpec.describe "Email delivery failures", type: :request do
  let(:ssl_error) { OpenSSL::SSL::SSLError.new("SSL_read: unexpected eof while reading") }

  def stub_email_delivery_to_raise(error)
    allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now).and_raise(error)
    allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_later).and_raise(error)
    allow_any_instance_of(Mail::Message).to receive(:deliver).and_raise(error)
  end

  describe "PasswordsController#create" do
    let(:user) { create(:user) }

    it "rescues SSL errors and shows a flash alert instead of 500ing" do
      user # create before stubbing
      stub_email_delivery_to_raise(ssl_error)

      post user_password_path, params: { user: { email: user.email } }

      expect(response).to redirect_to(anything)
      follow_redirect!
      expect(response.body).to include("Email failed to send")
    end
  end

  describe "ConfirmationsController#create" do
    let(:unconfirmed_user) { create(:user, confirmed_at: nil) }

    it "rescues SSL errors and shows a flash alert instead of 500ing" do
      unconfirmed_user # create before stubbing
      stub_email_delivery_to_raise(ssl_error)

      post user_confirmation_path, params: { user: { email: unconfirmed_user.email } }

      expect(response).to redirect_to(anything)
      follow_redirect!
      expect(response.body).to include("Email failed to send")
    end
  end

  describe "ContactUsController#create" do
    it "rescues SSL errors and shows a flash alert instead of 500ing" do
      stub_email_delivery_to_raise(ssl_error)

      post contact_us_path, params: {
        contact_us: {
          first_name: "Jane",
          last_name: "Smith",
          from: "jane@example.com",
          agency: "Test Agency",
          subject: "Test Subject",
          message: "Test message",
          q: "general"
        }
      }

      expect(response).to redirect_to(anything)
      follow_redirect!
      expect(response.body).to include("Email failed to send")
    end
  end
end
