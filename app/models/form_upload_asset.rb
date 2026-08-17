# A file a respondent attached to a form answer, as opposed to an asset an
# author picked for a Story/Workshop/Event. It takes Asset's full accepted-type
# list — documents included — because the upload field offers those types.
#
# The distinct type matters: assets.type defaults to "PrimaryAsset", so building
# an answer's asset without naming a type silently produces one, and PrimaryAsset
# narrows ACCEPTED_CONTENT_TYPES to five image types. Every document the form
# advertises would then fail validation and take the whole registration with it.
#
# Deliberately absent from Asset::TYPES — that list drives the author-facing
# asset-type picker, and these are never chosen there.
class FormUploadAsset < Asset
end
