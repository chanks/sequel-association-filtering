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

          other_class = reflection.associated_class

          dataset = reflection.associated_dataset
          dataset = yield dataset if block_given?

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

          dataset = dataset.where(local_keys => remote_keys)

          where(dataset.select(1).exists)
        end
      end
    end
  end
end
