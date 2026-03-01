require "rails_helper"

RSpec.describe RemoteSearchable, type: :model do
  describe ".remote_search" do
    let(:admin) { create(:user, :admin) }

    let!(:alice) { create(:person, first_name: "Alice", last_name: "Smith", email: "alice@example.com", created_by: admin, updated_by: admin) }
    let!(:bob) { create(:person, first_name: "Bob", last_name: "Smith", email: "bob@example.com", created_by: admin, updated_by: admin) }
    let!(:carol) { create(:person, first_name: "Carol", last_name: "Jones", email: "carol@test.org", created_by: admin, updated_by: admin) }

    context "with a single term" do
      it "matches first name" do
        expect(Person.remote_search("Alice")).to include(alice)
        expect(Person.remote_search("Alice")).not_to include(bob, carol)
      end

      it "matches last name" do
        results = Person.remote_search("Smith")
        expect(results).to include(alice, bob)
        expect(results).not_to include(carol)
      end

      it "matches email" do
        results = Person.remote_search("carol@test")
        expect(results).to include(carol)
        expect(results).not_to include(alice, bob)
      end

      it "matches email_2" do
        person = create(:person, first_name: "Dana", last_name: "White", email: nil, email_2: "dana@secondary.org", created_by: admin, updated_by: admin)
        results = Person.remote_search("dana@secondary")
        expect(results).to include(person)
      end

      it "matches user email" do
        user = create(:user, email: "unique-login@corp.com")
        person = user.person
        results = Person.remote_search("unique-login@corp")
        expect(results).to include(person)
      end

      it "matches partial strings" do
        expect(Person.remote_search("ali")).to include(alice)
      end

      it "is case insensitive" do
        expect(Person.remote_search("ALICE")).to include(alice)
      end
    end

    context "with multiple terms" do
      it "matches across different columns" do
        results = Person.remote_search("Alice Smith")
        expect(results).to include(alice)
        expect(results).not_to include(bob, carol)
      end

      it "matches regardless of term order" do
        results = Person.remote_search("Smith Alice")
        expect(results).to include(alice)
        expect(results).not_to include(bob)
      end

      it "matches partial terms across columns" do
        results = Person.remote_search("ali smi")
        expect(results).to include(alice)
        expect(results).not_to include(bob, carol)
      end

      it "matches names containing spaces" do
        mary_ann = create(:person, first_name: "Mary Ann", last_name: "De La Cruz", email: "ma@example.com", created_by: admin, updated_by: admin)

        expect(Person.remote_search("Mary Ann")).to include(mary_ann)
        expect(Person.remote_search("Ann Cruz")).to include(mary_ann)
        expect(Person.remote_search("De La")).to include(mary_ann)
      end

      it "requires all terms to match" do
        results = Person.remote_search("Alice Jones")
        expect(results).not_to include(alice, carol)
      end
    end

    context "with a blank query" do
      it "returns no results" do
        expect(Person.remote_search("")).to be_empty
        expect(Person.remote_search("   ")).to be_empty
      end
    end
  end
end
