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
    when Affiliation then [ "#{record.person&.full_name} at #{record.organization&.name}", edit_affiliation_path(record) ]
    when Payment then [ [ dollars_from_cents(record.amount_cents), record.payer&.name ].compact.join(" from "), payment_path(record) ]
    when Workshop then [ record.title, workshop_path(record) ]
    end

    link_to text, path, class: button_classes(:primary)
  end

  # The archive record an ID field points at, or an unsaved placeholder when the archive has none.
  def fm_archive_record(fm_id, table)
    model = FmArchivesController::TABLES.fetch(table.delete_prefix("fm_"))[:model]
    model.find_by(fm_id: fm_id) || model.new(fm_id: fm_id, data: {})
  end

  # A record's FileMaker ID, linked to its archive page, or struck through when the archive lacks it.
  def fm_archive_id_tag(record)
    unless record.persisted?
      return tag.span(record.fm_id, class: "ml-1 font-mono text-xs font-normal text-gray-400 line-through", title: "No FM record found")
    end

    link_to record.fm_id, fm_archive_record_path(record), class: "ml-1 font-mono text-xs font-normal text-primary hover:underline"
  end

  # What a record is, linked to its archive page, or a not-found note when the archive lacks it.
  def fm_archive_summary_tag(record)
    return tag.span("Not found in FM data", class: "text-gray-500 italic") unless record.persisted?

    summary = record.class.decorator_class? ? record.decorate.try(:summary).presence : nil
    link_to summary || record.name, fm_archive_record_path(record), class: "text-primary hover:underline"
  end

  def fm_archive_record_path(record)
    fm_archive_path(record.fm_id, table: record.class.table_name.delete_prefix("fm_"))
  end

  # The portal's name for a related table's counterpart, when the archive's label doesn't already lead with it.
  def fm_portal_counterpart_name(record, table, label)
    name = record.portal_counterpart(table)
    name unless name.nil? || label.downcase.start_with?(name.downcase)
  end

  # Colors a related table orange when the portal keeps its own records of the same kind.
  def fm_related_table_highlight(record, table)
    "border-orange-200 bg-orange-100" if record.portal_counterpart(table)
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
