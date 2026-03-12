require "rails_helper"
require "rake"

RSpec.describe "legacy:user_permissions_to_comments" do
  before(:all) do
    Rails.application.load_tasks
  end

  before do
    Rake::Task["legacy:user_permissions_to_comments"].reenable

    # Define lightweight AR models if they don't exist yet, so the task can run.
    unless defined?(Permission)
      class Permission < ApplicationRecord
        self.table_name = "permissions"
      end
    end

    unless defined?(UserPermission)
      class UserPermission < ApplicationRecord
        self.table_name = "user_permissions"
      end
    end
  end

  def run_task
    Rake::Task["legacy:user_permissions_to_comments"].invoke
  end

  let!(:user) { create(:user) }
  let!(:permission) { Permission.create!(security_cat: "Manage Reports") }

  it "creates a legacy comment on the user for each permission" do
    UserPermission.create!(user_id: user.id, permission_id: permission.id)

    expect { run_task }.to change { user.comments.count }.by(1)

    comment = user.comments.last
    expect(comment.body).to eq(
      "Legacy data note: user had permission to Manage Reports. " \
      "Deleted legacy permission tracking for all users on 2026-03-05.",
    )
  end

  it "is idempotent when run multiple times" do
    UserPermission.create!(user_id: user.id, permission_id: permission.id)

    run_task
    first_count = user.comments.count

    expect { run_task }.not_to change { user.comments.count }
    expect(user.comments.count).to eq(first_count)
  end
end

