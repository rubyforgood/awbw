module FilemakerHelper
  # One archive link per FileMaker code a record carries, since a record can answer to
  # several (see FilemakerCoded). A `label` names the button, adding each code only when
  # there are several to tell apart.
  def filemaker_code_links(record, link_class: nil, label: nil)
    codes = record.filemaker_codes
    filemaker_archive_links(codes, archives: record.class.filemaker_archives, link_class: link_class,
                                   label: label, show_code: label.nil? || codes.many?)
  end

  # Compact archive buttons that sit beside a record's FileMaker code input.
  def filemaker_code_chips(record)
    filemaker_archive_links(record.filemaker_codes, archives: record.class.filemaker_archives,
                                                    label: tag.i(class: "fa-solid fa-box-archive", aria: { hidden: true }),
                                                    link_class: button_classes(:primary_outline, size: :sm, extra: "bg-white"))
  end

  # An org's codes are FileMaker projects; this links the agency each project sits under.
  def filemaker_agency_links(organization, link_class: nil, label: nil)
    agency_ids = FmProject.where(fm_id: organization.filemaker_codes).filter_map { |project| project.data["OrgID"].presence }.uniq
    filemaker_archive_links(agency_ids, archives: [ FmOrganization ], link_class: link_class,
                                        label: label, show_code: label.nil? || agency_ids.many?)
  end

  # The way back from an archive row to the portal record carrying its code.
  def filemaker_portal_link(record)
    text, path = case record
    when Person then [ record.full_name, person_path(record) ]
    when Organization then [ record.name, organization_path(record) ]
    end

    link_to text, path, class: button_classes(:primary_outline, size: :sm)
  end

  # A code no archive table holds renders struck through, flagging a likely typo.
  def filemaker_archive_links(codes, archives:, link_class: nil, label: nil, show_code: true)
    return if codes.empty? || !allowed_to?(:show?, :fm_archive)

    stored = archives.index_with { |archive| archive.where(fm_id: codes).pluck(:fm_id).to_set }

    safe_join(codes.map do |code|
      text = show_code ? safe_join([ label, code ].compact, " ") : label
      archive = archives.find { |candidate| stored[candidate].include?(code) }
      # line-through! outranks a link_class `underline`, which sets the same text-decoration-line.
      next tag.span(text, class: [ link_class, "line-through! opacity-60" ], title: "No FileMaker archive record for #{code}") unless archive

      link_to text, fm_archive_path(code, table: archive.table_name.delete_prefix("fm_")),
              class: link_class, title: "Open #{code} in the FileMaker archive", target: "_blank", rel: "noopener"
    end, " ")
  end
end
