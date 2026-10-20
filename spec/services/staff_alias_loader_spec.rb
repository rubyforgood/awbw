require "rails_helper"

RSpec.describe StaffAliasLoader do
  let!(:by_id) { create(:user, email: "jamie@example.com") }
  let!(:by_email) { create(:user, email: "theo@example.com") }

  def load(rows, col_sep: "\t")
    file = Tempfile.new([ "staff", ".tsv" ])
    file.write(rows.map { |row| row.join(col_sep) }.join("\n"))
    file.close
    described_class.call(file.path, quiet: true)
  ensure
    file&.unlink
  end

  let(:header) { %w[staff fm_emails portal_user_email user_ids_by_email entered] }

  it "records each name against the user its id or email names" do
    load([
      header,
      [ "Jamie Rivera", "", "jamie@example.com", by_id.id, "12" ],
      [ "Jamie", "", "", by_id.id, "3" ],
      [ "Theo Brandt", "theo@example.org", "Theo@Example.com", "", "40" ]
    ])

    expect(StaffAlias.pluck(:name, :user_id)).to contain_exactly(
      [ "Jamie Rivera", by_id.id ], [ "Jamie", by_id.id ], [ "Theo Brandt", by_email.id ]
    )
  end

  it "records a name marked ignored as naming no one" do
    load([ header + [ "ignored" ], [ "Staff", "", "", "", "900", "yes" ] ])

    expect(StaffAlias.ignored.pluck(:name)).to eq([ "Staff" ])
  end

  it "reports a name no user answers to rather than recording it" do
    loader = load([ header, [ "Office Laptop", "", "", "", "9" ], [ "Delia", "", "nobody@example.com", "", "2" ] ])

    expect(loader.unresolved).to eq([ "Office Laptop", "Delia" ])
    expect(StaffAlias.count).to eq(0)
  end

  it "leaves a name already recorded alone, so a hand correction survives a re-run" do
    create(:staff_alias, name: "Jamie Rivera", user: by_email)

    loader = load([ header, [ "jamie rivera", "", "jamie@example.com", by_id.id, "12" ] ])

    expect(loader.kept).to eq(1)
    expect(StaffAlias.find_by(name: "Jamie Rivera").user).to eq(by_email)
  end

  it "reads a comma-separated list too" do
    load([ %w[staff user_ids_by_email], [ "Jamie Rivera", by_id.id ] ], col_sep: ",")

    expect(StaffAlias.pluck(:name)).to eq([ "Jamie Rivera" ])
  end
end
