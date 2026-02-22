# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkInviteService do
  before { allow($stdout).to receive(:puts) }

  describe ".call" do
    it "delegates to a new instance" do
      user = create(:user)
      results = described_class.call(ids: [user.id], dry_run: true)

      expect(results[:missing_ids]).to be_empty
    end
  end

  describe "#call" do
    context "when no users are found" do
      it "returns empty results with missing IDs" do
        results = described_class.call(ids: [999_999])

        expect(results[:sent]).to be_empty
        expect(results[:failed]).to be_empty
        expect(results[:missing_ids]).to eq([999_999])
      end
    end

    context "with dry_run" do
      it "does not modify users or enqueue jobs" do
        user = create(:user)

        expect {
          described_class.call(ids: [user.id], dry_run: true)
        }.not_to have_enqueued_job(BulkInviteEmailJob)

        user.reload
        expect(user.welcome_instructions_token).to be_nil
        expect(user.welcome_instructions_sent_at).to be_nil
      end

      it "returns empty sent and failed arrays" do
        user = create(:user)
        results = described_class.call(ids: [user.id], dry_run: true)

        expect(results[:sent]).to be_empty
        expect(results[:failed]).to be_empty
      end
    end

    context "with valid users" do
      it "sets welcome instructions token and sent_at" do
        user = create(:user)
        described_class.call(ids: [user.id])

        user.reload
        expect(user.welcome_instructions_token).to be_present
        expect(user.welcome_instructions_sent_at).to be_present
      end

      it "nils out created_at" do
        user = create(:user)
        described_class.call(ids: [user.id])

        user.reload
        expect(user.created_at).to be_nil
      end

      it "enqueues a BulkInviteEmailJob per user" do
        users = create_list(:user, 3)

        expect {
          described_class.call(ids: users.map(&:id))
        }.to have_enqueued_job(BulkInviteEmailJob).exactly(3).times
      end

      it "returns sent users in results" do
        user = create(:user)
        results = described_class.call(ids: [user.id])

        expect(results[:sent]).to contain_exactly(
          hash_including(id: user.id, email: user.email)
        )
      end
    end

    context "with a mix of valid and invalid IDs" do
      it "reports missing IDs and still processes valid ones" do
        user = create(:user)
        results = described_class.call(ids: [user.id, 999_999])

        expect(results[:missing_ids]).to eq([999_999])
        expect(results[:sent].size).to eq(1)
      end
    end

    context "when a user fails" do
      it "records the failure and continues processing remaining users" do
        bad_user, good_user = create_list(:user, 2)

        call_count = 0
        allow_any_instance_of(User).to receive(:set_welcome_instructions_token!).and_wrap_original do |method, *args|
          call_count += 1
          raise StandardError, "boom" if call_count == 1
          method.call(*args)
        end

        results = described_class.call(ids: [bad_user.id, good_user.id])

        expect(results[:failed].size).to eq(1)
        expect(results[:failed].first).to include(id: bad_user.id, error: "boom")
        expect(results[:sent].size).to eq(1)
        expect(results[:sent].first[:id]).to eq(good_user.id)
      end

      it "does not roll back other users' transactions" do
        bad_user, good_user = create_list(:user, 2)

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
