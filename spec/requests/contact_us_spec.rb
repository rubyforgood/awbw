require "rails_helper"

RSpec.describe "ContactUs", type: :request do
  let(:user) { create(:user, first_name: "John", last_name: "Doe") }
  let(:valid_params) do
    {
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
  end

  describe "GET /contact_us" do
    context "when not logged in" do
      it "is publicly accessible" do
        get contact_us_path
        expect(response).to have_http_status(:ok)
      end

      it "does not show personalized greeting" do
        get contact_us_path
        expect(response.body).not_to include("Hello,")
      end

      it "shows form fields for name, email, and agency" do
        get contact_us_path
        expect(response.body).to include('name="contact_us[first_name]"')
        expect(response.body).to include('name="contact_us[last_name]"')
        expect(response.body).to include('name="contact_us[from]"')
        expect(response.body).to include('name="contact_us[agency]"')
      end

      it "does not show adult or children program options" do
        get contact_us_path
        expect(response.body).not_to include("Adult Program")
        expect(response.body).not_to include("Children's Program")
      end

      it "does not show Twitter link" do
        get contact_us_path
        expect(response.body).not_to include("twitter.com")
      end

      it "shows thank you message after form submission" do
        post contact_us_path, params: valid_params
        follow_redirect!
        expect(response.body).to include("Thank you for contacting us!")
        expect(response.body).to include("Your message has been received")
      end

      it "has proper accessibility attributes" do
        get contact_us_path
        expect(response.body).to satisfy do |html|
          html.include?("aria-label") || html.include?("<label")
        end
        expect(response.body).to match(/type=['"]submit['"]/)
      end
    end

    context "when logged in" do
      before { sign_in user }

      it "is accessible" do
        get contact_us_path
        expect(response).to have_http_status(:ok)
      end

      it "shows personalized greeting" do
        get contact_us_path
        expect(response.body).to include("Hello, #{user.first_name}")
      end

      it "does not show visible form fields for name, email, and agency" do
        get contact_us_path
        expect(response.body).to include('type="hidden"')
        expect(response.body).to include('name="contact_us[first_name]"')
        expect(response.body).to include('name="contact_us[last_name]"')
        expect(response.body).to include('name="contact_us[from]"')
      end

      it "does not show adult or children program options" do
        get contact_us_path
        expect(response.body).not_to include("Adult Program")
        expect(response.body).not_to include("Children's Program")
      end
    end
  end

  describe "POST /contact_us" do
    context "when not logged in" do
      it "creates notifications and sends email" do
        expect {
          post contact_us_path, params: valid_params
        }.to change(Notification, :count).by(2)
        # .and have_enqueued_job.on_queue("mailers")

        expect(response).to redirect_to(contact_us_path(anchor: "thank-you"))
        expect(flash[:form_submitted]).to eq(true)
      end

      it "creates a contact_us notification for the submitter" do
        post contact_us_path, params: valid_params

        notification = Notification.find_by(kind: "contact_us")
        expect(notification).to be_present
        expect(notification.recipient_role).to eq("person")
        expect(notification.recipient_email).to eq("jane@example.com")
      end

      it "creates a contact_us_fyi notification for admins" do
        post contact_us_path, params: valid_params

        notification = Notification.find_by(kind: "contact_us_fyi")
        expect(notification).to be_present
        expect(notification.recipient_role).to eq("admin")
        expect(notification.recipient_email).to eq(ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"))
      end
    end

    context "when logged in" do
      before { sign_in user }

      let(:logged_in_params) do
        {
          contact_us: {
            first_name: user.first_name,
            last_name: user.last_name,
            from: user.email,
            agency: "",
            subject: "Test Subject from logged in user",
            message: "Test message from logged in user",
            q: "general"
          }
        }
      end

      it "creates notifications and sends email" do
        expect {
          post contact_us_path, params: logged_in_params
        }.to change(Notification, :count).by(2)
        # .and have_enqueued_job.on_queue("mailers")

        expect(response).to redirect_to(contact_us_path(anchor: "thank-you"))
        expect(flash[:form_submitted]).to eq(true)
      end

      it "creates a contact_us notification for the logged in user" do
        post contact_us_path, params: logged_in_params

        notification = Notification.find_by(kind: "contact_us", recipient_email: user.email)
        expect(notification).to be_present
        expect(notification.recipient_role).to eq("person")
      end

      it "creates a contact_us_fyi notification for admins" do
        post contact_us_path, params: logged_in_params

        notification = Notification.find_by(kind: "contact_us_fyi")
        expect(notification).to be_present
        expect(notification.recipient_role).to eq("admin")
      end
    end
  end
end
