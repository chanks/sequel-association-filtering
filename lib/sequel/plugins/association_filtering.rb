require 'sequel'
require 'sequel/plugins/association_filtering/version'

module Sequel
  module Plugins
    module AssociationFiltering
      class Error < StandardError; end

      module ClassMethods
        Plugins.def_dataset_methods(self, :association_filter)
      end

      module DatasetMethods
        def association_filter(association_name)
          reflection =
            model.association_reflections.fetch(association_name) do
              raise Error, "association #{association_name} not found on model #{model}"
            end

          dataset =
            cached_dataset(:"_association_filter_#{association_name}") do
              ds = reflection.associated_dataset

              case t = reflection[:type]
              when :one_to_many
                local_keys  = reflection.qualified_primary_key
                remote_keys = reflection.predicate_key
              when :many_to_one
                local_keys  = reflection[:qualified_key]
                remote_keys = reflection.qualified_primary_key
              else
                raise Error, "Unsupported reflection type: #{t}"
              end

              ds.where(local_keys => remote_keys).select(1)
            end

          dataset = yield dataset if block_given?

          where(dataset.exists)
        end
      end
    end
  end
end
