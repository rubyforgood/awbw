# give it a specific seed to ensure the same data is generated. This combined
# with running rspec with a specific seed value will ensure that specs are run
# in the same order and the same "faked" data is generated each time: giving
# us deterministic results.
Faker::Config.random = Random.new(42)