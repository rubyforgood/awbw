module FilemakerHelper
  # One archive link per FileMaker code a record carries, since a record can answer to
  # several (see FilemakerCoded). A code the archive has no row for renders as plain
  # text. `label` prefixes each link, for a button or hint that has to read as an action.
  def filemaker_code_links(record, archive:, table:, link_class: nil, label: nil)
    codes = record.filemaker_codes
    return if codes.empty?

    stored = archive.where(fm_id: codes).pluck(:fm_id).to_set

    safe_join(codes.map do |code|
      text = [ label, code ].compact.join(" ")
      next tag.span(text) unless stored.include?(code)

      link_to text, fm_archive_path(code, table: table), class: link_class, target: "_blank", rel: "noopener"
    end, " ")
  end
end
