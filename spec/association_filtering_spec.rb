require 'spec_helper'

class AssociationFilteringSpec < AssociationFilteringSpecs
  describe "association_filter" do
    it "with an unknown association should throw an error" do
      error =
        assert_raises(Sequel::Plugins::AssociationFiltering::Error) do
          Album.association_filter(:widgets)
        end

      assert_equal "association widgets not found on model Album", error.message
    end

    describe "through a many_to_one association" do
      it "should support a simple filter" do
        ds = Album.association_filter(:artist){|a| a.where{mod(id, 5) =~ 0}}
        assert_equal 20, ds.count

        record = ds.order_by{random.function}.first
        assert_includes [5, 10], record.artist_id
      end
    end

    describe "through a one_to_many association" do
      it "should support a simple filter" do
        ds = Album.association_filter(:tracks){|t| t.where(id: 40)}
        assert_equal 1, ds.count

        record = ds.first!
        assert_includes record.tracks.map(&:id), 40
      end

      it "should support an empty filter that checks for existence" do
        ds = Album.association_filter(:tracks)
        assert_equal 100, ds.count

        Track.where(album_id: 50).delete
        assert_equal 99, ds.count
      end
    end

    describe "through a many_to_many_association" do
      it "should support a simple filter"

      it "should support an empty filter that checks for existence"
    end
  end
end
