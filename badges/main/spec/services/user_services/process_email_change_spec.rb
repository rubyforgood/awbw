require "rails_helper"

RSpec.describe UserServices::ProcessEmailChange do
  let(:admin) { create(:user, :admin) }

  describe ".call" do
    let(:user) { create(:user) }

    before do
      user.update_columns(unconfirmed_email: "new@example.com")
    end

    context "with send_confirmation true" do
      let(:mock_mail) { double(deliver_later: true, deliver: true, deliver_now: true) }

      before do
        allow(DeviseMailer).to receive(:confirmation_instructions).and_return(mock_mail)
      end

      it "sends confirmation to the pending email" do
        described_class.call(
          user: user,
          send_confirmation: true,
          current_user: admin
        )

        expect(DeviseMailer).to have_received(:confirmation_instructions)
          .with(user, anything, hash_including(to: "new@example.com"))
      end

      it "includes confirmation message in summary" do
        result = described_class.call(
          user: user,
          send_confirmation: true,
          current_user: admin
        )

        expect(result.summary).to include("confirmation email has been sent to new@example.com")
      end
    end

    context "with send_confirmation false" do
      it "does not send confirmation instructions" do
        expect(user).not_to receive(:send_confirmation_instructions)

        described_class.call(
          user: user,
          send_confirmation: false,
          current_user: admin
        )
      end

      it "returns default summary" do
        result = described_class.call(
          user: user,
          send_confirmation: false,
          current_user: admin
        )

        expect(result.summary).to eq("User was successfully updated.")
        expect(result.actions_taken).to be_empty
      end
    end

    context "when unconfirmed_email is blank" do
      before { user.update_columns(unconfirmed_email: nil) }

      it "does not send email even when requested" do
        expect(user).not_to receive(:send_confirmation_instructions)

        result = described_class.call(
          user: user,
          send_confirmation: true,
          current_user: admin
        )

        expect(result.actions_taken).to be_empty
      end
    end
  end
end
