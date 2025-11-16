class AddCombinedPermsToExistingUsers < ActiveRecord::Migration
  def change
    User.find_in_batches do |group|
      group.each do |user|
        # combined_perm = user.permissions.find_by(security_cat: "Combined Adult and Children's Windows")
        # if combined_perm.nil?
        #   user.permissions << Permission.new(security_cat: "Combined Adult and Children's Windows")
        # end
      end
    end
  end
end
