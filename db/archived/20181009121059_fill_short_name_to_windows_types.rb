class FillShortNameToWindowsTypes < ActiveRecord::Migration
  def change
    WindowsType.all.each do |w|
      if w.name.include? 'COMBINED'
        w.update(:short_name => 'COMBINED')
      else
        w.update(:short_name => w.name.split(" ")[0])
      end  
    end  
  end
end
