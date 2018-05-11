# frozen_string_literal: true

require 'sequel'

require './lib/sequel-association-filtering'

Sequel::Model.plugin :association_filtering

DB = Sequel.connect "postgres:///sequel-association-filtering-test"

require 'pry'
require 'minitest/autorun'
require 'minitest/pride'

class AssociationFilteringSpecs < Minitest::Spec
  def around
    DB.transaction(rollback: :always) { super }
  end
end
