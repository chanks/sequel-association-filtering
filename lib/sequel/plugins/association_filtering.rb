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

          if block_given?
            ds = yield(_association_filter_dataset(reflection))
            where(ds.exists)
          else
            cached_dataset(_association_filter_cache_key(reflection, suffix: :bare)) do
              where(_association_filter_dataset(reflection).exists)
            end
          end
        end

        private

        def _association_filter_dataset(reflection)
          cache_key = _association_filter_cache_key(reflection)

          ds = reflection.associated_dataset

          ds.send(:cached_dataset, cache_key) do
            case t = reflection[:type]
            when :one_to_many
              local_keys  = reflection.qualified_primary_key
              remote_keys = reflection.predicate_key
            when :many_to_one
              local_keys  = reflection[:qualified_key]
              remote_keys = reflection.qualified_primary_key
            when :many_to_many
              local_keys  = reflection.qualify_cur(reflection[:left_primary_key])
              remote_keys = reflection.qualified_left_key
            else
              raise Error, "Unsupported reflection type: #{t}"
            end

            ds.where(remote_keys => local_keys).select(1)
          end
        end

        def _association_filter_cache_key(reflection, suffix: nil)
          :"_association_filter_#{reflection[:model]}_#{reflection[:name]}_#{suffix}"
        end
      end
    end
  end
end
