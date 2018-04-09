require 'spec_helper'

class AssociationFilteringSpec < AssociationFilteringSpecs
  describe "association_filter through a many_to_one association" do
    it "should support a simple filter" do
      ds = Album.association_filter(:artist){|a| a.where{mod(id, 5) =~ 0}}
      assert_equal 20, ds.count
      assert_equal %(SELECT * FROM "albums" WHERE (EXISTS (SELECT 1 FROM "artists" WHERE (("artists"."id" = "albums"."artist_id") AND (mod("id", 5) = 0)) LIMIT 1))), ds.sql

      record = ds.order_by{random.function}.first
      assert_includes [5, 10], record.artist_id
    end
  end
end
