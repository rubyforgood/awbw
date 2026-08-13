# Reseed Faker's RNG before every example so each example draws from the same
# fixed sequence regardless of test order. Faker uses one shared, global stream,
# so without this a factory's "random" value depends on how many Faker calls ran
# earlier in the suite — making data order-dependent and specs flaky under some
# seeds (e.g. an address factory landing on country "Canada"). Reseeding per
# example makes the faked data deterministic AND independent of ordering.
Faker::Config.random = Random.new(42)

RSpec.configure do |config|
  config.before(:each) do
    Faker::Config.random = Random.new(42)
    # Faker's .unique generator remembers used values for the whole run; reseeding
    # to the same stream would replay them and hit RetryLimitExceeded, so clear it.
    Faker::UniqueGenerator.clear
  end
end
