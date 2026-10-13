module FilemakerHelper
  # One archive link per FileMaker code a record carries, since a record can answer to
  # several (see FilemakerCoded). A `label` names the button, adding each code only when
  # there are several to tell apart.
  def filemaker_code_links(record, link_class: nil, label: nil, linked_only: false)
    filemaker_archive_links(record.filemaker_codes, archives: record.class.filemaker_archives,
                                                    link_class: link_class, label: label, linked_only: linked_only)
  end

  # The hint under a FileMaker code input, linking each code to its archive record.
  def filemaker_code_hint(record)
    links = filemaker_code_links(record, link_class: "text-blue-600 underline hover:text-blue-800")
    safe_join([ "In the archive:", links ], " ") if links
  end

  # The FM projects among an org's codes.
  def filemaker_project_links(organization, link_class: nil, label: nil, linked_only: false)
    project_ids = FmProject.where(fm_id: organization.filemaker_codes).pluck(:fm_id)
    filemaker_archive_links(project_ids, archives: [ FmProject ], link_class: link_class, label: label, linked_only: linked_only)
  end

  # The FM organizations among an org's codes, plus the one each of its projects sits under.
  def filemaker_organization_links(organization, link_class: nil, label: nil, linked_only: false)
    codes = organization.filemaker_codes
    parent_ids = FmProject.where(fm_id: codes).filter_map { |project| project.data["OrgID"].presence }
    fm_organization_ids = (FmOrganization.where(fm_id: codes).pluck(:fm_id) + parent_ids).uniq
    filemaker_archive_links(fm_organization_ids, archives: [ FmOrganization ],
                                                 link_class: link_class, label: label, linked_only: linked_only)
  end

  # The way back from an archive row to the portal record carrying its code.
  def filemaker_portal_link(record)
    text, path = case record
    when Person then [ record.full_name, person_path(record) ]
    when Organization then [ record.name, organization_path(record) ]
    end

    link_to text, path, class: button_classes(:primary_outline, size: :sm)
  end

  # A code no archive table holds renders struck through, flagging a likely typo —
  # or is dropped with `linked_only`, for nav buttons that must all lead somewhere.
  def filemaker_archive_links(codes, archives:, link_class: nil, label: nil, linked_only: false)
    return if codes.empty? || !allowed_to?(:show?, :fm_archive)

    stored = archives.index_with { |archive| archive.where(fm_id: codes).pluck(:fm_id).to_set }
    archive_by_code = codes.index_with { |code| archives.find { |candidate| stored[candidate].include?(code) } }
    archive_by_code.compact! if linked_only
    return if archive_by_code.empty?

    show_code = label.nil? || archive_by_code.many?

    safe_join(archive_by_code.map do |code, archive|
      text = show_code ? safe_join([ label, code ].compact, " ") : label
      # line-through! outranks a link_class `underline`, which sets the same text-decoration-line.
      next tag.span(text, class: [ link_class, "line-through! opacity-60" ], title: "No FileMaker archive record for #{code}") unless archive

      link_to text, fm_archive_path(code, table: archive.table_name.delete_prefix("fm_")),
              class: link_class, title: "Open #{code} in the FileMaker archive", target: "_blank", rel: "noopener"
    end, " ")
  end
end
