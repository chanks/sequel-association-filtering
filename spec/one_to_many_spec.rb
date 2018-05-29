# frozen_string_literal: true

require 'spec_helper'

class OneToManySpec < AssociationFilteringSpecs
  describe "with a singular primary_key" do
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
        one_to_many :albums, class: 'OneToManySpec::Album'
      end

      class Album < Sequel::Model
        many_to_one :artist, class: 'OneToManySpec::Artist'
      end
    end

    after do
      OneToManySpec.send(:remove_const, :Artist)
      OneToManySpec.send(:remove_const, :Album)
      drop_tables
    end

    def drop_tables
      DB.drop_table? :albums, :artists
    end

    describe "association_filter through a one_to_many association" do
      it "should support a simple filter" do
        ds = Artist.association_filter(:albums){|t| t.where(id: 40)}
        assert_equal 1, ds.count
        assert_equal %(SELECT * FROM "artists" WHERE (EXISTS (SELECT 1 FROM "albums" WHERE (("albums"."artist_id" = "artists"."id") AND ("id" = 40))))), ds.sql

        artist = ds.first!
        assert_includes artist.albums.map(&:id), 40
      end

      it "should support an empty filter that checks for existence" do
        ds = Artist.association_filter(:albums)
        assert_equal 10, ds.count
        assert_equal %(SELECT * FROM "artists" WHERE (EXISTS (SELECT 1 FROM "albums" WHERE ("albums"."artist_id" = "artists"."id")))), ds.sql

        Album.where(artist_id: 5).delete
        assert_equal 9, ds.count
      end

      it "should support at_least/exactly/at_most args" do
        Album.create(artist_id: 1)

        ds = Artist.association_filter(:albums, exactly: 11)
        assert_equal 1, ds.count
        assert_equal %(SELECT * FROM "artists" WHERE (EXISTS (SELECT 1 FROM "albums" WHERE ("albums"."artist_id" = "artists"."id") GROUP BY "albums"."artist_id" HAVING (count(*) = 11)))), ds.sql
        assert_equal [1], ds.select_map(:id)

        ds = Artist.association_filter(:albums, at_least: 2){|albums| albums.where{id > 90}}
        assert_equal 1, ds.count
        assert_equal %(SELECT * FROM "artists" WHERE (EXISTS (SELECT 1 FROM "albums" WHERE (("albums"."artist_id" = "artists"."id") AND ("id" > 90)) GROUP BY "albums"."artist_id" HAVING (count(*) >= 2)))), ds.sql
        assert_equal [1], ds.select_map(:id)

        ds = Artist.association_filter(:albums, at_most: 1){|albums| albums.where{id > 90}}
        assert_equal 9, ds.count
        assert_equal %(SELECT * FROM "artists" WHERE (EXISTS (SELECT 1 FROM "albums" WHERE (("albums"."artist_id" = "artists"."id") AND ("id" > 90)) GROUP BY "albums"."artist_id" HAVING (count(*) <= 1)))), ds.sql
        assert_equal (2..10).to_a, ds.select_order_map(:id)
      end
    end
  end

  describe "with a composite primary key" do
    before do
      drop_tables

      DB.create_table :artists do
        integer :id_1, null: false
        integer :id_2, null: false
        serial :serial_column

        primary_key [:id_1, :id_2]
      end

      DB.create_table :albums do
        integer :id_1, null: false
        integer :id_2, null: false
        integer :id_3, null: false
        serial :serial_column

        primary_key [:id_1, :id_2, :id_3]
        foreign_key [:id_1, :id_2], :artists
      end

      DB.run <<-SQL
        INSERT INTO artists (id_1, id_2)       SELECT i,j   FROM generate_series(1, 10) i CROSS JOIN generate_series(1, 10) j;
        INSERT INTO albums  (id_1, id_2, id_3) SELECT i,j,k FROM generate_series(1, 10) i CROSS JOIN generate_series(1, 10) j CROSS JOIN generate_series(1, 10) k;
      SQL

      class Artist < Sequel::Model
        set_primary_key [:id_1, :id_2]

        one_to_many :albums, class: 'OneToManySpec::Album', key: [:id_1, :id_2]
      end

      class Album < Sequel::Model
        set_primary_key [:id_1, :id_2, :id_3]

        many_to_one :artist, class: 'OneToManySpec::Artist', key: [:id_1, :id_2]
      end
    end

    after do
      OneToManySpec.send(:remove_const, :Artist)
      OneToManySpec.send(:remove_const, :Album)
      drop_tables
    end

    def drop_tables
      DB.drop_table? :albums, :artists
    end

    describe "association_filter through a one_to_many association" do
      it "should support a simple filter" do
        ds = Artist.association_filter(:albums){|t| t.where(serial_column: 40)}

        assert_equal 1, ds.count
        assert_equal %(SELECT * FROM "artists" WHERE (EXISTS (SELECT 1 FROM "albums" WHERE (("albums"."id_1" = "artists"."id_1") AND ("albums"."id_2" = "artists"."id_2") AND ("serial_column" = 40))))), ds.sql

        artist = ds.first!
        assert_includes artist.albums.map(&:serial_column), 40
      end

      it "should support an empty filter that checks for existence" do
        ds = Artist.association_filter(:albums)
        assert_equal 100, ds.count
        assert_equal %(SELECT * FROM "artists" WHERE (EXISTS (SELECT 1 FROM "albums" WHERE (("albums"."id_1" = "artists"."id_1") AND ("albums"."id_2" = "artists"."id_2"))))), ds.sql

        Album.where(id_1: 5, id_2: 6).delete
        assert_equal 99, ds.count
      end

      it "should support at_least/exactly/at_most args" do
        Album.dataset.insert(id_1: 1, id_2: 1, id_3: 11)

        ds = Artist.association_filter(:albums, exactly: 11)
        assert_equal 1, ds.count
        assert_equal %(SELECT * FROM "artists" WHERE (EXISTS (SELECT 1 FROM "albums" WHERE (("albums"."id_1" = "artists"."id_1") AND ("albums"."id_2" = "artists"."id_2")) GROUP BY "albums"."id_1", "albums"."id_2" HAVING (count(*) = 11)))), ds.sql
        assert_equal [[1, 1]], ds.select_map([:id_1, :id_2])

        ds = Artist.association_filter(:albums, at_least: 2){|albums| albums.where{serial_column > 900}}
        assert_equal 1, ds.count
        assert_equal %(SELECT * FROM "artists" WHERE (EXISTS (SELECT 1 FROM "albums" WHERE (("albums"."id_1" = "artists"."id_1") AND ("albums"."id_2" = "artists"."id_2") AND ("serial_column" > 900)) GROUP BY "albums"."id_1", "albums"."id_2" HAVING (count(*) >= 2)))), ds.sql
        assert_equal [[1, 1]], ds.select_map([:id_1, :id_2])

        ds = Artist.association_filter(:albums, at_most: 1){|albums| albums.where{serial_column > 900}}
        assert_equal 99, ds.count
        assert_equal %(SELECT * FROM "artists" WHERE (EXISTS (SELECT 1 FROM "albums" WHERE (("albums"."id_1" = "artists"."id_1") AND ("albums"."id_2" = "artists"."id_2") AND ("serial_column" > 900)) GROUP BY "albums"."id_1", "albums"."id_2" HAVING (count(*) <= 1)))), ds.sql
        assert_equal (2..100).to_a, ds.select_order_map(:serial_column)
      end
    end

    describe "association_exclude through a one_to_many association" do
      it "should support a simple filter" do
        ds = Artist.association_exclude(:albums){|t| t.where(serial_column: 40)}

        assert_equal 99, ds.count
        assert_equal %(SELECT * FROM "artists" WHERE NOT (EXISTS (SELECT 1 FROM "albums" WHERE (("albums"."id_1" = "artists"."id_1") AND ("albums"."id_2" = "artists"."id_2") AND ("serial_column" = 40))))), ds.sql

        artists = ds.all
        refute_includes artists.flat_map(&:albums).map(&:serial_column), 40
      end

      it "should support an empty filter that checks for existence" do
        ds = Artist.association_exclude(:albums)
        assert_equal 0, ds.count
        assert_equal %(SELECT * FROM "artists" WHERE NOT (EXISTS (SELECT 1 FROM "albums" WHERE (("albums"."id_1" = "artists"."id_1") AND ("albums"."id_2" = "artists"."id_2"))))), ds.sql

        Album.where(id_1: 5, id_2: 6).delete
        assert_equal 1, ds.count
      end
    end
  end
end
