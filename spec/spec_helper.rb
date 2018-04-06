require 'sequel'

require './lib/sequel-association-filtering'

Sequel::Model.plugin :association_filtering

DB = Sequel.connect "postgres:///sequel-association-filtering-test"

DB.drop_table? :album_genres, :genres, :tracks, :albums, :artists

DB.create_table :artists do
  primary_key :id
end

DB.create_table :albums do
  primary_key :id
  foreign_key :artist_id, :artists
end

DB.create_table :tracks do
  primary_key :id
  foreign_key :album_id, :albums
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

class Artist < Sequel::Model
  one_to_many :albums
end

class Album < Sequel::Model
  many_to_one :artist
  one_to_many :tracks

  many_to_many :genres, join_table: :album_genres
end

class Track < Sequel::Model
  many_to_one :album
end

class Genre < Sequel::Model
  many_to_many :albums, join_table: :album_genres
end

DB.run <<-SQL
  INSERT INTO artists SELECT i FROM generate_series(1, 10) i;
  INSERT INTO albums (artist_id) SELECT (i % 10) + 1 FROM generate_series(1, 100) i;
  INSERT INTO tracks (album_id) SELECT (i % 100) + 1 FROM generate_series(1, 1000) i;
  INSERT INTO genres SELECT i FROM generate_series(1, 10) i;

  INSERT INTO album_genres (album_id, genre_id)
    SELECT DISTINCT ceil(random() * 100), ceil(random() * 10) FROM generate_series(1, 300);
SQL

require 'pry'
require 'minitest/autorun'
require 'minitest/pride'

class AssociationFilteringSpecs < Minitest::Spec
  def around
    DB.transaction(rollback: :always) { super }
  end
end
