class FormBuilderDecorator < Draper::Decorator
  delegate_all

  def new_report_url
    if workshop_but_not_family_windows?
      h.workshop_log_creation_wizard_path(:fill_out_form, {windows_type_id: windows_type_id})
    else
      h.report_path(:fill_out_form, form_builder_id: id)
    end
  end

  private

  def workshop_but_not_family_windows?
    name.include?('Log') && name != 'Family Workshop Log'
  end
end
