json.content record.title.present? ? record.title : record.id
json.sgid record.attachable_sgid
json.contentType record.attachable_content_type
