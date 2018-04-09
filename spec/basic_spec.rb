require 'spec_helper'

class BasicSpec < AssociationFilteringSpecs
  describe "association_filter" do
    it "with an unknown association should throw an error" do
      error =
        assert_raises(Sequel::Plugins::AssociationFiltering::Error) do
          Album.association_filter(:widgets)
        end

      assert_equal "association widgets not found on model Album", error.message
    end
  end
end
