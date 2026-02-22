# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkInviteService do
  before { allow($stdout).to receive(:puts) }

  describe ".call" do
    it "delegates to a new instance" do
      user = create(:user, :unconfirmed)
      results = described_class.call(ids: [user.id], dry_run: true)

      expect(results[:missing_ids]).to be_empty
    end
  end

  describe "#call" do
    context "when no users are found" do
      it "returns empty results with missing IDs" do
        results = described_class.call(ids: [999_999])

        expect(results[:sent_ids]).to be_empty
        expect(results[:failed]).to be_empty
        expect(results[:missing_ids]).to eq([999_999])
      end
    end

    context "with dry_run" do
      it "does not modify users or enqueue jobs" do
        user = create(:user, :unconfirmed)

        expect {
          described_class.call(ids: [user.id], dry_run: true)
        }.not_to have_enqueued_job(BulkInviteEmailJob)

        user.reload
        expect(user.welcome_instructions_token).to be_nil
        expect(user.welcome_instructions_sent_at).to be_nil
      end

      it "returns user IDs that would be sent in dry_run_would_send" do
        user = create(:user, :unconfirmed)
        results = described_class.call(ids: [user.id], dry_run: true)

        expect(results[:dry_run_would_send_ids]).to eq([user.id])
        expect(results).not_to have_key(:sent_ids)
        expect(results).not_to have_key(:failed)
      end
    end

    context "with valid users" do
      it "sets welcome instructions token and sent_at" do
        user = create(:user, :unconfirmed)
        described_class.call(ids: [user.id])

        user.reload
        expect(user.welcome_instructions_token).to be_present
        expect(user.welcome_instructions_sent_at).to be_present
      end

      it "nils out created_at" do
        user = create(:user, :unconfirmed)
        described_class.call(ids: [user.id])

        user.reload
        expect(user.created_at).to be_nil
      end

      it "enqueues a BulkInviteEmailJob per user" do
        users = create_list(:user, 3, :unconfirmed)

        expect {
          described_class.call(ids: users.map(&:id))
        }.to have_enqueued_job(BulkInviteEmailJob).exactly(3).times
      end

      it "returns sent user IDs in results" do
        user = create(:user, :unconfirmed)
        results = described_class.call(ids: [user.id])

        expect(results[:sent_ids]).to eq([user.id])
      end
    end

    context "with already confirmed users" do
      it "skips confirmed users and reports them" do
        confirmed_user = create(:user)
        unconfirmed_user = create(:user, :unconfirmed)

        results = described_class.call(ids: [confirmed_user.id, unconfirmed_user.id])

        expect(results[:already_confirmed_ids]).to eq([confirmed_user.id])
        expect(results[:sent_ids]).to eq([unconfirmed_user.id])
      end

      it "does not enqueue jobs for confirmed users" do
        confirmed_user = create(:user)

        expect {
          described_class.call(ids: [confirmed_user.id])
        }.not_to have_enqueued_job(BulkInviteEmailJob)
      end
    end

    context "with a mix of valid and invalid IDs" do
      it "reports missing IDs and still processes valid ones" do
        user = create(:user, :unconfirmed)
        results = described_class.call(ids: [user.id, 999_999])

        expect(results[:missing_ids]).to eq([999_999])
        expect(results[:sent_ids].size).to eq(1)
      end
    end

    context "when a user fails" do
      it "records the failure and continues processing remaining users" do
        bad_user, good_user = create_list(:user, 2, :unconfirmed)

        call_count = 0
        allow_any_instance_of(User).to receive(:set_welcome_instructions_token!).and_wrap_original do |method, *args|
          call_count += 1
          raise StandardError, "boom" if call_count == 1
          method.call(*args)
        end

        results = described_class.call(ids: [bad_user.id, good_user.id])

        expect(results[:failed].size).to eq(1)
        expect(results[:failed].first).to include(id: bad_user.id, error: "boom")
        expect(results[:sent_ids]).to eq([good_user.id])
      end

      it "does not roll back other users' transactions" do
        bad_user, good_user = create_list(:user, 2, :unconfirmed)

        call_count = 0
        allow_any_instance_of(User).to receive(:set_welcome_instructions_token!).and_wrap_original do |method, *args|
          call_count += 1
          raise StandardError, "boom" if call_count == 1
          method.call(*args)
        end

        described_class.call(ids: [bad_user.id, good_user.id])

        good_user.reload
        expect(good_user.welcome_instructions_token).to be_present
        expect(good_user.created_at).to be_nil
      end
    end
  end
end
