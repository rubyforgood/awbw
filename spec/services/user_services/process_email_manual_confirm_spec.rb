require "rails_helper"

RSpec.describe UserServices::ProcessEmailManualConfirm do
  let(:admin) { create(:user, :admin) }

  describe ".call" do
    context "with an unconfirmed account" do
      let(:user) { create(:user, confirmed_at: nil) }

      context "with action 'resend'" do
        let(:mock_mail) { double(deliver_later: true, deliver: true) }

        before do
          allow(DeviseMailer).to receive(:confirmation_instructions).and_return(mock_mail)
        end

        it "sends confirmation to the user's email" do
          described_class.call(
            user: user,
            action: "resend",
            current_user: admin
          )

          expect(DeviseMailer).to have_received(:confirmation_instructions)
            .with(user, anything, hash_including(to: user.email))
        end

        it "includes resent message with user email in summary" do
          result = described_class.call(
            user: user,
            action: "resend",
            current_user: admin
          )

          expect(result.summary).to include("Confirmation email has been resent to #{user.email}")
        end
      end

      context "with action 'confirm'" do
        it "confirms the user" do
          described_class.call(
            user: user,
            action: "confirm",
            current_user: admin
          )

          user.reload
          expect(user.confirmed_at).not_to be_nil
        end

        it "includes manually confirmed message in summary" do
          result = described_class.call(
            user: user,
            action: "confirm",
            current_user: admin
          )

          expect(result.summary).to include("Email has been manually confirmed")
        end
      end
    end

    context "with a pending email change" do
      let(:user) { create(:user) }
      let(:new_email) { "newemail@example.com" }

      before do
        user.update_columns(unconfirmed_email: new_email)
      end

      context "with action 'resend'" do
        let(:mock_mail) { double(deliver_later: true, deliver: true) }

        before do
          allow(DeviseMailer).to receive(:confirmation_instructions).and_return(mock_mail)
        end

        it "sends confirmation to the pending email" do
          described_class.call(
            user: user,
            action: "resend",
            current_user: admin
          )

          expect(DeviseMailer).to have_received(:confirmation_instructions)
            .with(user, anything, hash_including(to: new_email))
        end

        it "does not send to the current email" do
          described_class.call(
            user: user,
            action: "resend",
            current_user: admin
          )

          expect(DeviseMailer).not_to have_received(:confirmation_instructions)
            .with(user, anything, hash_including(to: user.email))
        end

        it "includes the pending email in summary" do
          result = described_class.call(
            user: user,
            action: "resend",
            current_user: admin
          )

          expect(result.summary).to include("Confirmation email has been resent to #{new_email}")
        end
      end

      context "with action 'confirm'" do
        it "moves unconfirmed_email to email" do
          described_class.call(
            user: user,
            action: "confirm",
            current_user: admin
          )

          user.reload
          expect(user.email).to eq(new_email)
          expect(user.unconfirmed_email).to be_nil
        end

        it "includes email change confirmed message in summary" do
          result = described_class.call(
            user: user,
            action: "confirm",
            current_user: admin
          )

          expect(result.summary).to include("Email change to #{new_email} has been manually confirmed")
        end
      end
    end

    context "with no action" do
      let(:user) { create(:user, confirmed_at: nil) }

      it "takes no action" do
        result = described_class.call(
          user: user,
          action: nil,
          current_user: admin
        )

        expect(result.summary).to eq("No action taken.")
        expect(result.actions_taken).to be_empty
        user.reload
        expect(user.confirmed_at).to be_nil
      end
    end
  end
end
