# One-off repair

SOURCE_PERSON_ID = 3072
ORIGINAL_EXTERNAL_PAYER_ID = 3158      # the External Payer before the merge
REPLACEMENT_EXTERNAL_PAYER_ID = 36568  # the External Payer created after it
ORIGINAL_CREATED_AT = Time.utc(2026, 6, 14, 19, 56, 30)

payment_ids = PaperTrail::Version.where(item_type: "Payment", event: "create").filter_map do |version|
  changes = version.object_changes
  changes = YAML.unsafe_load(changes) if changes.is_a?(String)
  next unless changes.is_a?(Hash)

  version.item_id if Array(changes["person_id"]).last == ORIGINAL_EXTERNAL_PAYER_ID
end

replacement = Person.find_by(id: REPLACEMENT_EXTERNAL_PAYER_ID)
replacement&.update_column(:external_payer, nil)

payer = Person.find_by(id: ORIGINAL_EXTERNAL_PAYER_ID)
if payer
  payer.update_column(:external_payer, true)
else
  # Free the "External Payer" name so the restored record validates.
  replacement&.update_column(:first_name, "External (retired)")
  payer = Person.create!(
    id: ORIGINAL_EXTERNAL_PAYER_ID,
    first_name: "External",
    last_name: "Payer",
    external_payer: true,
    created_at: ORIGINAL_CREATED_AT
  )
end

moved = 0
Payment.transaction do
  moved += Payment.where(person_id: replacement.id).update_all(person_id: payer.id) if replacement
  moved += Payment.where(id: payment_ids, person_id: SOURCE_PERSON_ID).update_all(person_id: payer.id)
end

replacement&.destroy!

puts "External Payer: ##{payer.id} (#{payer.full_name})"
puts "Moved #{moved} payments"
puts "Payment 920 payer: ##{Payment.find(920).person_id} (#{Payment.find(920).versions.count} version(s))"
puts "Replacement ##{REPLACEMENT_EXTERNAL_PAYER_ID} exists: #{Person.exists?(REPLACEMENT_EXTERNAL_PAYER_ID)}"
