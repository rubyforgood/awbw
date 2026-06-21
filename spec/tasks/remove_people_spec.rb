require "rails_helper"
require "rake"

# Behaviour is covered in spec/services/people_remover_spec.rb. These specs just
# confirm the rake task wires ENV → PeopleRemover correctly.
RSpec.describe "data:remove_people" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("data:remove_people")
  end

  before { Rake::Task["data:remove_people"].reenable }

  def run_task(env = {})
    keys = %w[PERSON_IDS FORM_SUBMISSION_IDS CONFIRM DELETE_USERS FORCE]
    saved = keys.index_with { |k| ENV[k] }
    keys.each { |k| ENV.delete(k) }
    env.each { |k, v| ENV[k.to_s] = v.to_s }
    suppress_output { Rake::Task["data:remove_people"].invoke }
  ensure
    Rake::Task["data:remove_people"].reenable
    keys.each { |k| ENV[k] = saved[k] }
  end

  def suppress_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
  ensure
    $stdout = original_stdout
  end

  it "aborts when no ids are given" do
    expect { run_task }.to raise_error(SystemExit)
  end

  it "deletes nothing without CONFIRM (dry run)" do
    person = create(:person, user: nil)
    create(:form_submission, person: person)

    expect { run_task(PERSON_IDS: person.id) }.not_to change(Person, :count)
    expect(Person.exists?(person.id)).to be true
  end

  it "deletes the targeted person with CONFIRM=true" do
    person = create(:person, user: nil)
    create(:form_submission, person: person)

    run_task(PERSON_IDS: person.id, CONFIRM: true)

    expect(Person.exists?(person.id)).to be false
  end
end
