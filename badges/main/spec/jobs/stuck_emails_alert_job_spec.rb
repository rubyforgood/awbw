require "rails_helper"

RSpec.describe StuckEmailsAlertJob, type: :job do
  before { allow(Honeybadger).to receive(:notify) }

  def stuck(created_at: 2.hours.ago)
    create(:notification, kind: "event_registration_confirmation", created_at: created_at)
  end

  it "alerts Honeybadger when emails stalled in the last day" do
    2.times { stuck }

    described_class.perform_now

    expect(Honeybadger).to have_received(:notify)
      .with("2 portal emails stuck pending", hash_including(error_class: "StuckEmails", fingerprint: "stuck_emails"))
  end

  it "stays quiet when nothing has stalled" do
    create(:notification, kind: "event_registration_confirmation")

    described_class.perform_now

    expect(Honeybadger).not_to have_received(:notify)
  end

  it "ignores emails that stalled more than a day ago" do
    stuck(created_at: 3.days.ago)

    described_class.perform_now

    expect(Honeybadger).not_to have_received(:notify)
  end

  it "is scheduled in production" do
    recurring = YAML.load(ERB.new(Rails.root.join("config/recurring.yml").read).result)

    expect(recurring.dig("production", "stuck_emails_alert", "class")).to eq(described_class.name)
  end
end
