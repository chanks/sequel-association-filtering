require 'spec_helper'

class AssociationFilteringSpec < AssociationFilteringSpecs
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
end
