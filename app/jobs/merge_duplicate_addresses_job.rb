class MergeDuplicateAddressesJob < ApplicationJob
  SOURCE = "address_dedupe".freeze

  queue_as :default
  limits_concurrency key: "all", on_conflict: :discard, duration: 1.hour

  def perform(user = nil)
    tracker = Ahoy::Tracker.new(user: user)
    Current.set(user: user, source: SOURCE) do
      AddressServices::DuplicateFinder.new.groups.each { |group| merge(group, tracker) }
    end
  end

  private

  def merge(group, tracker)
    ActiveRecord::Base.transaction do
      AddressDeduper.merge_duplicates(group.addressable)
      Analytics::LifecycleBuffer.flush_to(tracker)
    end
  rescue StandardError => e
    Analytics::LifecycleBuffer.store.clear
    Rails.error.report(e, context: { addressable: group.addressable.to_global_id.to_s })
  end
end
