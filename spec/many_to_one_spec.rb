require 'spec_helper'

class ManyToOneSpec < AssociationFilteringSpecs
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
      one_to_many :albums, class: 'ManyToOneSpec::Album'
    end

    class Album < Sequel::Model
      many_to_one :artist, class: 'ManyToOneSpec::Artist'
    end
  end

  after do
    drop_tables
  end

  def drop_tables
    DB.drop_table? :albums, :artists
  end

  describe "association_filter through a many_to_one association" do
    it "should support a simple filter" do
      ds = Album.association_filter(:artist){|a| a.where{mod(id, 5) =~ 0}}
      assert_equal 20, ds.count
      assert_equal %(SELECT * FROM "albums" WHERE (EXISTS (SELECT 1 FROM "artists" WHERE (("artists"."id" = "albums"."artist_id") AND (mod("id", 5) = 0)) LIMIT 1))), ds.sql

      record = ds.order_by{random.function}.first
      assert_includes [5, 10], record.artist_id
    end
  end

  describe "association_exclude through a many_to_one association" do
    it "should support a simple filter" do
      ds = Album.association_exclude(:artist){|a| a.where{mod(id, 5) =~ 0}}
      assert_equal 80, ds.count
      assert_equal %(SELECT * FROM "albums" WHERE NOT (EXISTS (SELECT 1 FROM "artists" WHERE (("artists"."id" = "albums"."artist_id") AND (mod("id", 5) = 0)) LIMIT 1))), ds.sql

      record = ds.order_by{random.function}.first
      refute_includes [5, 10], record.artist_id
    end
  end
end
