class RenameAutorenewalCancelledAtOnMemberships < ActiveRecord::Migration[8.1]
  def change
    rename_column :memberships, :autorenewal_cancelled_at, :renewal_off_at
  end
end
