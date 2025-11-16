class CreateUserForOrphanedReports < ActiveRecord::Migration
  def up
    user = User.new(first_name: "Orphaned", last_name: "Reports", email: "orphaned_reports@awbw.org", password: "awbworphaned")
    user.save!
    # user.permissions << Permission.new(security_cat: "Children's Windows")
    # user.permissions << Permission.new(security_cat: "Adult Windows")
    # user.permissions << Permission.new(security_cat: "Combined Adult and Children's Windows")

    ProjectUser.create(user_id: user.id, position: 2, project_id: Project.first.id)
  end

  def down
    user = User.find_by(email: "orphaned_reports@awbw.org")
    ProjectUser.where(user_id: user.id).destroy_all
    user.destroy
  end
end
