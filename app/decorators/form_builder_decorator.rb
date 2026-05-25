class FormBuilderDecorator < ApplicationDecorator
  def new_report_url
    return unless workshop_but_not_family_windows?
    h.new_workshop_log_path(windows_type_id: windows_type_id)
  end

  private

  def workshop_but_not_family_windows?
    name.include?("Log") && name != "Family Workshop Log"
  end
end
