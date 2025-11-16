class FixUserPerms < ActiveRecord::Migration
  def change
    # UserPermission.delete_all
    # Permission.delete_all
    #
    # Permission.create(security_cat: "Children's Windows")
    # Permission.create(security_cat: "Adult Windows")
    # Permission.create(security_cat: "Combined Adult and Children's Windows")
    #
    # User.find_in_batches do |group|
    #   group.each do |user|
    #     combined_perm = Permission.find_by(security_cat: "Combined Adult and Children's Windows")
    #     user.permissions << combined_perm
    #   end
    # end
  end
end
