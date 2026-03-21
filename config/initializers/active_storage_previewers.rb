Rails.application.config.active_storage.previewers = [
  ActiveStorage::Previewer::MuPDFPreviewer,    # move MuPDF to first for high-quality PDFs
  ActiveStorage::Previewer::PopplerPDFPreviewer,
  ActiveStorage::Previewer::VideoPreviewer
]
