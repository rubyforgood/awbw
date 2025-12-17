module RhinoEditorHelper
  def rhino_editor_field(form, base_name)
    rhino_attr = :"rhino_#{base_name}"
    field_id = form.field_id(rhino_attr)
    value = form.object.public_send(rhino_attr)

    safe_join([
      form.hidden_field(
        rhino_attr,
        id: field_id,
        value: value.respond_to?(:to_trix_html) ? value.to_trix_html : value
      ),
      content_tag(
        :"rhino-editor",
        nil,
        input: field_id,
        data: {
          blob_url_template: rails_service_blob_url(":signed_id", ":filename"),
          direct_upload_url: rails_direct_uploads_url
        }
      )
    ])
  end
end
