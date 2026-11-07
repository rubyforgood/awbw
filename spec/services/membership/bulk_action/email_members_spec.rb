require "rails_helper"

RSpec.describe Membership::BulkAction::EmailMembers do
  let(:directory) { MembershipDirectory.new({}) }
  let(:action) { described_class.new }

  def membership_for(person)
    create(:membership, person:)
  end

  describe "#preview_rows" do
    it "marks a member with portal access actionable and shows their login email" do
      membership = membership_for(create(:person))

      row = action.preview_rows(directory, ids: [ membership.id ]).sole

      expect(row.actionable).to be(true)
      expect(row.email).to eq(membership.person.user.email)
      expect(row.flags).to be_empty
      expect(row.detail).to eq("No invoice")
    end

    it "flags no portal access and leaves the row not actionable" do
      membership = membership_for(create(:person, :without_user))

      row = action.preview_rows(directory, ids: [ membership.id ]).sole

      expect(row.actionable).to be(false)
      expect(row.flags).to include("No portal access")
    end

    it "flags a locked membership and leaves the row not actionable" do
      membership = membership_for(create(:person))
      membership.update_column(:locked_at, Time.current)

      row = action.preview_rows(directory, ids: [ membership.id ]).sole

      expect(row.actionable).to be(false)
      expect(row.flags).to include("Locked")
    end

    it "shows the invoice period when one exists" do
      membership = membership_for(create(:person))
      invoice = create(:membership_invoice, membership:, start_date: Date.current,
        end_date: Date.current + Membership::INVOICE_PERIOD - 1.day, cost_cents: 10_000)

      row = action.preview_rows(directory, ids: [ membership.id ]).sole

      expect(row.detail).to include(invoice.start_date.strftime("%b %-d, %Y"))
    end
  end

  describe "#perform" do
    let(:admin) { create(:user, :admin) }

    it "queues an onboarding notification for each member with portal access" do
      membership = membership_for(create(:person))
      result = nil

      expect {
        Current.set(user: admin) { result = action.perform(directory, ids: [ membership.id ]) }
      }.to have_enqueued_job(NotificationMailerJob)

      expect(result.changed).to eq(1)
      expect(result.skipped).to eq(0)

      notification = Notification.where(kind: "membership_onboarding").sole
      expect(notification.noticeable).to eq(membership)
      expect(notification.person).to eq(membership.person)
      expect(notification.recipient_email).to eq(membership.person.user.email)
      expect(notification.sender).to eq(admin)
      expect(notification.bulk).to be(true)
    end

    it "skips members without portal access" do
      membership = membership_for(create(:person, :without_user))
      result = nil

      expect {
        result = action.perform(directory, ids: [ membership.id ])
      }.not_to have_enqueued_job(NotificationMailerJob)

      expect(result.changed).to eq(0)
      expect(result.skipped).to eq(1)
    end

    it "skips locked memberships" do
      membership = membership_for(create(:person))
      membership.update_column(:locked_at, Time.current)
      result = nil

      expect {
        result = action.perform(directory, ids: [ membership.id ])
      }.not_to have_enqueued_job(NotificationMailerJob)

      expect(result.changed).to eq(0)
      expect(result.skipped).to eq(1)
    end
  end
end
