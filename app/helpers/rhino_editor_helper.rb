module RhinoEditorHelper
  # custom rhino editor with stimulus controller attached to edit raw source html
  def rhino_editor(form, base_attribute_name, label: nil, hint: nil)
    rhino_attr = :"rhino_#{base_attribute_name}"
    field_id = form.field_id(rhino_attr)
    value = form.object.public_send(rhino_attr)

    label_tag =
      if label.present?
        form.label(
          base_attribute_name,
          label,
          class: "block font-medium mb-1 text-gray-700 text optional"
        )
      end

    hint_tag =
      if hint.present?
        content_tag(
          :p,
          hint,
          class: "text-gray-500 text-sm mt-1"
        )
      end

    hidden = form.hidden_field(
      rhino_attr,
      id: field_id,
      value: value.respond_to?(:to_trix_html) ? value.to_trix_html : value
    )

    modal = content_tag(
      :div,
      data: { rhino_source_target: "modal" },
      class: "hidden fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
    ) do
      content_tag(:div, class: "bg-white p-4 rounded shadow-lg w-3/4 max-w-2xl") do
        safe_join([
          content_tag(:h2, "Edit HTML", class: "text-lg font-bold mb-2"),
          content_tag(
            :textarea,
            nil,
            data: { rhino_source_target: "textarea" },
            class: "w-full h-64 p-2 border rounded"
          ),
          content_tag(:div, class: "mt-2 text-right") do
            safe_join([
              content_tag(
                :button,
                "Cancel",
                data: { action: "click->rhino-source#hide" },
                class: "mr-2 px-4 py-2 bg-gray-200 rounded"
              ),
              content_tag(
                :button,
                "Save",
                data: { action: "click->rhino-source#save" },
                class: "px-4 py-2 bg-blue-600 text-white rounded"
              )
            ])
          end
        ])
      end
    end

    editor = content_tag(
      :"custom-rhino-editor",
      nil,
      input: field_id,
      data: {
        blob_url_template: rails_service_blob_url(":signed_id", ":filename"),
        direct_upload_url: rails_direct_uploads_url,
        model_sgid: form.object.persisted? ? form.object.to_sgid.to_s : nil
      }
    )

    content_tag(:div, data: { controller: "rhino-source" }, class: "mb-4 prose max-w-none") do
      safe_join([
        label_tag,
        editor,
        hint_tag,
        modal,
        hidden
      ].compact)
    end
  end
end
