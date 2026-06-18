module PaymentsHelper
  # Builds the single preselected option ([ label, sgid ]) for a compound
  # people + organizations picker, so the dropdown shows the current selection
  # before TomSelect loads remote results. Returns [] when nothing is selected.
  def party_select_options(record, sgid)
    return [] if record.blank? || sgid.blank?
    [ [ record.compound_search_label[:label], sgid ] ]
  end
end
