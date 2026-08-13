require "rails_helper"

# Exercises the before_notify hook registered in config/initializers/honeybadger.rb,
# which drops the benign closed-connection error a SolidQueue pod raises while
# deregistering itself during shutdown, without hiding real DB outages.
RSpec.describe "Honeybadger shutdown filter" do
  def run_hooks(error_class:, error_message:, component:)
    notice = instance_double(
      Honeybadger::Notice,
      error_class: error_class,
      error_message: error_message,
      component: component
    )
    allow(notice).to receive(:halt!)
    Honeybadger.config.before_notify_hooks.each { |hook| hook.call(notice) }
    notice
  end

  it "drops a closed-connection error raised outside any request (pod shutdown noise)" do
    notice = run_hooks(
      error_class: "ActiveRecord::ConnectionNotEstablished",
      error_message: "trilogy_connect - unable to connect to db:25060: TRILOGY_CLOSED_CONNECTION",
      component: nil
    )

    expect(notice).to have_received(:halt!)
  end

  it "keeps a closed-connection error raised during a request" do
    notice = run_hooks(
      error_class: "ActiveRecord::ConnectionNotEstablished",
      error_message: "trilogy_connect - ...: TRILOGY_CLOSED_CONNECTION",
      component: "GrantsController"
    )

    expect(notice).not_to have_received(:halt!)
  end

  it "keeps a genuine can't-reach-the-database error" do
    notice = run_hooks(
      error_class: "ActiveRecord::ConnectionNotEstablished",
      error_message: "trilogy_connect - unable to connect: Connection refused",
      component: nil
    )

    expect(notice).not_to have_received(:halt!)
  end
end
