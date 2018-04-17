require 'spec_helper'

class BasicSpec < AssociationFilteringSpecs
  before do
    DB.create_table :artists do
      primary_key :id
    end

    DB.run <<-SQL
      INSERT INTO artists SELECT i FROM generate_series(1, 10) i;
    SQL

    class Artist < Sequel::Model
    end
  end

  after do
    DB.drop_table? :artists
  end

  describe "association_filter" do
    it "with an unknown association should throw an error" do
      error =
        assert_raises(Sequel::Plugins::AssociationFiltering::Error) do
          Artist.association_filter(:widgets)
        end

      assert_equal "association widgets not found on model BasicSpec::Artist", error.message
    end
  end
end