Rails.application.config.after_initialize do
  Rails.application.config.active_storage.previewers.unshift HighResPopplerPdfPreviewer
end
