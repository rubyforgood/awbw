class GiveAllUsersFullPerms < ActiveRecord::Migration
  def change
    # puts

    # User.find_in_batches do |group|
    #
    #   group.each do |user|
    #
    #     ["Children's Windows", "Adult Windows", "Combined Adult and Children's Windows"].each do |sec_cat|
    #
    #       if user.permissions.find_by(security_cat: sec_cat).nil?
    #         print "."
    #         perm = Permission.find_by(security_cat: sec_cat)
    #         user.permissions << perm
    #       end
    #
    #     end
    #   end
    # end
  end
end
