require "rails_helper"

RSpec.describe BackgroundJobsStatus, :solid_queue do
  subject(:status) { described_class.new }

  let(:runner_alive) { true }

  before do
    allow(JobRunnerHealth).to receive(:alive?).and_return(runner_alive)
  end

  after do
    SolidQueue::Job.delete_all
  end

  def enqueue(class_name, at: Time.current)
    SolidQueue::Job.create!(queue_name: "default", class_name: class_name, arguments: {}, created_at: at).tap do |job|
      SolidQueue::ReadyExecution.where(job_id: job.id).update_all(created_at: at)
    end
  end

  def fail_job(job, error)
    SolidQueue::ReadyExecution.where(job_id: job.id).delete_all
    SolidQueue::FailedExecution.create!(job: job, exception: error)
  end

  describe "#light" do
    it "is green when the runner is alive and nothing is waiting long" do
      enqueue("NotificationMailerJob", at: 1.minute.ago)

      expect(status.light).to eq(:green)
    end

    context "when the runner has stopped checking in" do
      let(:runner_alive) { false }

      it { expect(status.light).to eq(:red) }
    end

    it "is yellow when a job has waited more than 15 minutes" do
      enqueue("NotificationMailerJob", at: 20.minutes.ago)

      expect(status.light).to eq(:yellow)
    end

    it "is red when a job has waited more than an hour" do
      enqueue("NotificationMailerJob", at: 2.hours.ago)

      expect(status.light).to eq(:red)
    end

    it "is yellow when jobs were interrupted by a dead runner" do
      fail_job(enqueue("NotificationMailerJob"), SolidQueue::Processes::ProcessPrunedError.new(1.hour.ago))

      expect(status.light).to eq(:yellow)
    end
  end

  describe "#waiting_by_job" do
    it "counts waiting jobs by class, most first" do
      enqueue("ActiveStorage::AnalyzeJob")
      2.times { enqueue("NotificationMailerJob") }

      expect(status.waiting_by_job).to eq("NotificationMailerJob" => 2, "ActiveStorage::AnalyzeJob" => 1)
      expect(status.waiting_count).to eq(3)
    end
  end

  describe ".label_for" do
    it "names known job kinds in plain language" do
      expect(described_class.label_for("Pay::Webhooks::ProcessJob")).to eq("Stripe payment updates")
    end

    it "falls back to the humanized class name" do
      expect(described_class.label_for("Reports::RebuildJob")).to eq("Rebuild job")
    end
  end

  describe "#retry_interrupted!" do
    it "re-queues jobs a dead runner interrupted and leaves ordinary failures alone" do
      interrupted = enqueue("NotificationMailerJob")
      fail_job(interrupted, SolidQueue::Processes::ProcessPrunedError.new(1.hour.ago))
      ordinary = enqueue("NotificationMailerJob")
      fail_job(ordinary, ActiveRecord::RecordNotFound.new("gone"))

      expect(status.retry_interrupted!).to eq(1)

      expect(SolidQueue::ReadyExecution.where(job_id: interrupted.id)).to exist
      expect(SolidQueue::FailedExecution.where(job_id: ordinary.id)).to exist
    end
  end
end
