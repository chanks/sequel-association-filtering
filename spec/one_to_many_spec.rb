require 'spec_helper'

class AssociationFilteringSpec < AssociationFilteringSpecs
  describe "association_filter through a one_to_many association" do
    it "should support a simple filter" do
      ds = Album.association_filter(:tracks){|t| t.where(id: 40)}
      assert_equal 1, ds.count
      assert_equal %(SELECT * FROM "albums" WHERE (EXISTS (SELECT 1 FROM "tracks" WHERE (("tracks"."album_id" = "albums"."id") AND ("id" = 40))))), ds.sql

      record = ds.first!
      assert_includes record.tracks.map(&:id), 40
    end

    it "should support an empty filter that checks for existence" do
      ds = Album.association_filter(:tracks)
      assert_equal 100, ds.count
      assert_equal %(SELECT * FROM "albums" WHERE (EXISTS (SELECT 1 FROM "tracks" WHERE ("tracks"."album_id" = "albums"."id")))), ds.sql

      Track.where(album_id: 50).delete
      assert_equal 99, ds.count
    end
  end
end
