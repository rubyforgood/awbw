class UpdateWindowsType < ActiveRecord::Migration
  def change
    wt = WindowsType.find_by(name: "Adult Windows")
    wt.update(name: "ADULT WORKSHOP LOG")

    wt = WindowsType.find_by(name: "Children's Windows")
    wt.update(name: "CHILDREN WORKSHOP LOG")

    wt = WindowsType.find_by(name: "Combined Adult and Children's Windows")
    wt.update(name: "ADULT & CHILDREN COMBINED (FAMILY) LOG")
  end
end
