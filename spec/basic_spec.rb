# frozen_string_literal: true

require 'spec_helper'

class BasicSpec < AssociationFilteringSpecs
  before do
    drop_tables

    DB.create_table :artists do
      primary_key :id
    end

    DB.create_table :albums do
      primary_key :id
      foreign_key :artist_id, :artists
    end

    DB.run <<-SQL
      INSERT INTO artists SELECT i FROM generate_series(1, 10) i;
      INSERT INTO albums (artist_id) SELECT (i % 10) + 1 FROM generate_series(1, 100) i;
    SQL

    class Artist < Sequel::Model
      one_to_many :albums, class: 'BasicSpec::Album'
    end

    class Album < Sequel::Model
      many_to_one :artist, class: 'BasicSpec::Artist'
    end
  end

  after do
    BasicSpec.send(:remove_const, :Artist)
    BasicSpec.send(:remove_const, :Album)
    drop_tables
  end

  def drop_tables
    DB.drop_table? :albums, :artists
  end

  describe "association_filter" do
    it "with an unknown association should throw an error" do
      error =
        assert_raises(Sequel::Plugins::AssociationFiltering::Error) do
          Artist.association_filter(:widgets)
        end

      assert_equal "association widgets not found on model BasicSpec::Artist", error.message
    end

    it "with more than one of at_least, at_most, or exactly should throw an error" do
      error =
        assert_raises(Sequel::Plugins::AssociationFiltering::Error) do
          Artist.association_filter(:widgets, at_most: 4, exactly: 5)
        end

      assert_equal "cannot pass more than one of :at_least, :at_most, and :exactly", error.message
    end

    it "should be able to return a cached dataset"
  end
end
