require "rails_helper"

RSpec.describe AffiliationPeriods do
  let(:today) { Date.new(2026, 7, 15) }

  # Lightweight stand-in for an affiliation — the service only reads dates.
  Interval = Struct.new(:start_date, :end_date)

  def label(*intervals)
    described_class.label(intervals, today: today)
  end

  it "returns nil when there are no affiliations" do
    expect(label).to be_nil
  end

  it "returns nil when no affiliation carries a start date" do
    expect(label(Interval.new(nil, nil))).to be_nil
  end

  describe "an ongoing period" do
    it "shows the month and year when it began this year" do
      expect(label(Interval.new(Date.new(2026, 7, 1), nil))).to eq("Jul 2026")
    end

    it "shows only the start year when it began in an earlier year" do
      expect(label(Interval.new(Date.new(2024, 3, 1), nil))).to eq("2024")
    end

    it "treats an end date today or later as ongoing" do
      expect(label(Interval.new(Date.new(2024, 3, 1), today))).to eq("2024")
    end
  end

  describe "a closed past period" do
    it "shows a single year when start and end fall in the same year" do
      expect(label(Interval.new(Date.new(2010, 3, 1), Date.new(2010, 9, 1)))).to eq("2010")
    end

    it "shows a year range across multiple years" do
      expect(label(Interval.new(Date.new(2010, 3, 1), Date.new(2016, 9, 1)))).to eq("2010-2016")
    end
  end

  it "merges overlapping intervals into one period" do
    expect(label(
      Interval.new(Date.new(2010, 1, 1), Date.new(2012, 6, 1)),
      Interval.new(Date.new(2011, 3, 1), Date.new(2012, 12, 1))
    )).to eq("2010-2012")
  end

  it "keeps gapped intervals as separate periods" do
    expect(label(
      Interval.new(Date.new(2010, 1, 1), Date.new(2012, 6, 1)),
      Interval.new(Date.new(2013, 1, 1), Date.new(2015, 6, 1))
    )).to eq("2010-2012, 2013-2015")
  end

  it "shows a past period alongside a current ongoing one" do
    expect(label(
      Interval.new(Date.new(2010, 1, 1), Date.new(2012, 6, 1)),
      Interval.new(Date.new(2026, 2, 1), nil)
    )).to eq("2010-2012, 2026")
  end

  it "orders periods chronologically regardless of input order" do
    expect(label(
      Interval.new(Date.new(2026, 2, 1), nil),
      Interval.new(Date.new(2010, 1, 1), Date.new(2012, 6, 1))
    )).to eq("2010-2012, 2026")
  end

  describe "month precision" do
    def month_label(*intervals)
      described_class.label(intervals, today: today, precision: :month)
    end

    it "shows the month on both ends of a closed period" do
      expect(month_label(Interval.new(Date.new(2015, 8, 1), Date.new(2018, 6, 1)))).to eq("Aug 2015 – Jun 2018")
    end

    it "shows only the start month for an ongoing period" do
      expect(month_label(Interval.new(Date.new(2015, 8, 1), nil))).to eq("Aug 2015")
    end

    it "keeps a lapse and a return as separate periods" do
      expect(month_label(
        Interval.new(Date.new(2015, 8, 1), Date.new(2018, 6, 1)),
        Interval.new(Date.new(2024, 2, 1), nil)
      )).to eq("Aug 2015 – Jun 2018, Feb 2024")
    end

    it "keeps the month even when a period starts and ends in the same year" do
      expect(month_label(Interval.new(Date.new(2010, 3, 1), Date.new(2010, 9, 1)))).to eq("Mar 2010 – Sep 2010")
    end

    it "returns nil when no affiliation carries a start date" do
      expect(month_label(Interval.new(nil, nil))).to be_nil
    end
  end

  it "rejects an unknown precision rather than silently formatting as years" do
    expect { described_class.label([], precision: :day) }.to raise_error(ArgumentError, /day/)
  end
end
