require "rails_helper"

RSpec.describe AddressLocality do
  def locality(city:, state:, **rest) = described_class.for(city:, state:, **rest)

  it "reads a Los Angeles address as LA City, whether or not the county came through" do
    expect(locality(city: "Los Angeles", state: "CA")).to eq("LA City")
    expect(locality(city: "los angeles", state: "California", county: "Los Angeles County")).to eq("LA City")
  end

  it "reads another city in Los Angeles County as LA County" do
    expect(locality(city: "Pasadena", state: "CA", county: "Los Angeles")).to eq("LA County")
  end

  it "reads an Orange County address as Orange County" do
    expect(locality(city: "Santa Ana", state: "CA", county: "Orange")).to eq("Orange County")
  end

  it "reads another US state as Outside CA" do
    expect(locality(city: "Cambridge", state: "MA")).to eq("Outside CA")
    expect(locality(city: "Austin", state: "Texas", county: "Travis")).to eq("Outside CA")
  end

  it "reads a country other than the US as Outside USA" do
    expect(locality(city: "Toronto", state: "ON", country: "Canada")).to eq("Outside USA")
    expect(locality(city: "Los Angeles", state: "CA", country: "Mexico")).to eq("Outside USA")
  end

  it "reads a City of Los Angeles neighborhood as LA City" do
    expect(locality(city: "Van Nuys", state: "CA")).to eq("LA City")
    expect(locality(city: "San Pedro", state: "CA", county: "Los Angeles")).to eq("LA City")
  end

  it "reads another California county by the region FileMaker projects place it in" do
    expect(locality(city: "Fresno", state: "CA", county: "Fresno")).to eq("Central CA")
    expect(locality(city: "Oakland", state: "CA", county: "Alameda County")).to eq("Northern CA")
    expect(locality(city: "San Diego", state: "CA", county: "San Diego")).to eq("Southern CA")
  end

  it "leaves a California address unknown when its county is missing or unplaced" do
    expect(locality(city: "Oakland", state: "CA")).to eq("Unknown")
    expect(locality(city: "Markleeville", state: "CA", county: "Alpine")).to eq("Unknown")
  end

  it "leaves a state no US state answers to unknown, since a typo and a foreign region read alike" do
    expect(locality(city: "Toronto", state: "ON")).to eq("Unknown")
    expect(locality(city: "Nowhere", state: "")).to eq("Unknown")
  end

  it "only ever answers with a locality the address form offers" do
    answers = [
      locality(city: "Los Angeles", state: "CA"), locality(city: "Pasadena", state: "CA", county: "Los Angeles"),
      locality(city: "Santa Ana", state: "CA", county: "Orange"), locality(city: "Cambridge", state: "MA"),
      locality(city: "Toronto", state: "ON", country: "Canada"), locality(city: "Fresno", state: "CA"),
      locality(city: "Fresno", state: "CA", county: "Fresno"), locality(city: "Oakland", state: "CA", county: "Alameda"),
      locality(city: "San Diego", state: "CA", county: "San Diego")
    ]

    expect(answers.uniq).to all(be_in(Address::LOCALITIES))
  end
end
