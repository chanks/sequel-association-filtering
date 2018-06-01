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

      dataset_module do
        subset :even_id, Sequel.lit('id % ? = 0', 2)
      end
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
      a, b = [:at_most, :exactly, :at_least].sample(2)

      error =
        assert_raises(Sequel::Plugins::AssociationFiltering::Error) do
          Artist.association_filter(:widgets, a => 4, b => 5)
        end

      assert_equal "cannot pass more than one of :at_least, :at_most, and :exactly", error.message
    end

    it "with an at_least/at_most/exactly that is not an integer should raise an error" do
      a = [:at_most, :exactly, :at_least].sample

      error =
        assert_raises(Sequel::Plugins::AssociationFiltering::Error) do
          Artist.association_filter(:widgets, a => Object.new)
        end

      assert_equal ":#{a} must be an Integer if present", error.message
    end

    describe "cached datasets" do
      let :seen_object_ids do
        Set.new
      end

      def assert_cached(*args, &block)
        ds1, ds2 = Array.new(2, Artist.association_filter(:albums, *args, &block))
        assert_equal ds1.object_id, ds2.object_id, ds1.sql
        assert seen_object_ids.add?(ds1.object_id), ds1.sql

        ds1, ds2 = Array.new(2, Artist.association_exclude(:albums, *args, &block))
        assert_equal ds1.object_id, ds2.object_id, ds1.sql
        assert seen_object_ids.add?(ds1.object_id), ds1.sql
      end

      def refute_cached(&block)
        ds1, ds2 = Array.new(2, &block)
        refute_equal ds1.object_id, ds2.object_id, ds1.sql
      end

      it "should be able to return a cached dataset" do
        assert_cached { Artist.association_filter(:albums) }
        assert_cached { Artist.association_filter(:albums, &:even_id) }

        assert_cached { Artist.association_filter(:albums, at_least: 2) }
        assert_cached { Artist.association_filter(:albums, at_least: 3) }
        assert_cached { Artist.association_filter(:albums, exactly:  2) }
        assert_cached { Artist.association_filter(:albums, at_most:  2) }

        assert_cached { Artist.association_filter(:albums, at_least: 2, &:even_id) }
      end

      it "should not cache potentially dynamic datasets" do
        refute_cached { Artist.association_filter(:albums){|a| a.where(artist_id: 2)} }
      end
    end
  end
end
