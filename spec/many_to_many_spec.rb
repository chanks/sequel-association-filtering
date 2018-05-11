# frozen_string_literal: true

require 'spec_helper'

class ManyToManySpec < AssociationFilteringSpecs
  before do
    drop_tables

    DB.create_table :albums do
      primary_key :id
    end

    DB.create_table :genres do
      primary_key :id
    end

    DB.create_table :album_genres do
      primary_key :id
      foreign_key :album_id, :albums
      foreign_key :genre_id, :genres

      unique [:album_id, :genre_id]
    end

    DB.run <<-SQL
      INSERT INTO albums SELECT i FROM generate_series(1, 100) i;
      INSERT INTO genres SELECT i FROM generate_series(1, 10) i;

      INSERT INTO album_genres (album_id, genre_id)
        SELECT DISTINCT ceil(random() * 100), ceil(random() * 10) FROM generate_series(1, 300);
    SQL

    class Album < Sequel::Model
      many_to_many :genres, class: 'ManyToManySpec::Genre', join_table: :album_genres
    end

    class Genre < Sequel::Model
      many_to_many :albums, class: 'ManyToManySpec::Album', join_table: :album_genres
    end
  end

  after do
    drop_tables
  end

  def drop_tables
    DB.drop_table? :album_genres, :genres, :albums
  end

  describe "association_filter through a many_to_many_association" do
    it "should support an empty filter that checks for existence" do
      expected_count = DB[:album_genres].distinct(:album_id).count

      ds = Album.association_filter(:genres)
      assert_equal %(SELECT * FROM "albums" WHERE (EXISTS (SELECT 1 FROM "genres" INNER JOIN "album_genres" ON ("album_genres"."genre_id" = "genres"."id") WHERE ("album_genres"."album_id" = "albums"."id")))), ds.sql
      assert_equal expected_count, ds.count

      album_id_to_delete = DB[:album_genres].order_by{random.function}.get(:album_id)

      DB[:album_genres].where(album_id: album_id_to_delete).delete
      assert_equal expected_count - 1, ds.count
    end

    it "should support a simple filter" do
      expected_count = DB[:album_genres].where(genre_id: 5).distinct(:album_id).count

      ds = Album.association_filter(:genres){|t| t.where(Sequel[:genres][:id] =~ 5)}
      assert_equal expected_count, ds.count
      assert_equal %(SELECT * FROM \"albums\" WHERE (EXISTS (SELECT 1 FROM "genres" INNER JOIN "album_genres" ON ("album_genres"."genre_id" = "genres"."id") WHERE (("album_genres"."album_id" = "albums"."id") AND ("genres"."id" = 5))))), ds.sql

      record = ds.first!
      assert_includes record.genres.map(&:id), 5
    end
  end

  describe "association_exclude through a many_to_many_association" do
    it "should support an empty filter that checks for existence" do
      expected_count = 100 - DB[:album_genres].distinct(:album_id).count

      ds = Album.association_exclude(:genres)
      assert_equal %(SELECT * FROM "albums" WHERE NOT (EXISTS (SELECT 1 FROM "genres" INNER JOIN "album_genres" ON ("album_genres"."genre_id" = "genres"."id") WHERE ("album_genres"."album_id" = "albums"."id")))), ds.sql
      assert_equal expected_count, ds.count

      album_id_to_delete = DB[:album_genres].order_by{random.function}.get(:album_id)

      DB[:album_genres].where(album_id: album_id_to_delete).delete
      assert_equal expected_count + 1, ds.count
    end

    it "should support a simple filter" do
      expected_count = 100 - DB[:album_genres].where(genre_id: 5).distinct(:album_id).count

      ds = Album.association_exclude(:genres){|t| t.where(Sequel[:genres][:id] =~ 5)}
      assert_equal expected_count, ds.count
      assert_equal %(SELECT * FROM \"albums\" WHERE NOT (EXISTS (SELECT 1 FROM "genres" INNER JOIN "album_genres" ON ("album_genres"."genre_id" = "genres"."id") WHERE (("album_genres"."album_id" = "albums"."id") AND ("genres"."id" = 5))))), ds.sql

      record = ds.first!
      refute_includes record.genres.map(&:id), 5
    end
  end
end
