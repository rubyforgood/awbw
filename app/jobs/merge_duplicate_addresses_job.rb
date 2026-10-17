class MergeDuplicateAddressesJob < ApplicationJob
  queue_as :default
  limits_concurrency key: "all", on_conflict: :discard, duration: 1.hour

  def perform
    AddressServices::DuplicateFinder.new.groups.each do |group|
      ActiveRecord::Base.transaction { AddressDeduper.merge_duplicates(group.addressable) }
    rescue StandardError => e
      Rails.error.report(e, context: { addressable: group.addressable.to_global_id.to_s })
    end
  end
end
