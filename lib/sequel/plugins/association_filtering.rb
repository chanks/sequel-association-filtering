require 'sequel'
require 'sequel/plugins/association_filtering/version'

module Sequel
  module Plugins
    module AssociationFiltering
      class Error < StandardError; end

      module ClassMethods
        Plugins.def_dataset_methods(
          self,
          [
            :association_filter,
            :association_exclude,
          ]
        )
      end

      module DatasetMethods
        def association_filter(association_name, invert: false)
          reflection =
            model.association_reflections.fetch(association_name) do
              raise Error, "association #{association_name} not found on model #{model}"
            end

          if block_given?
            cond = yield(_association_filter_dataset(reflection)).exists
            invert ? exclude(cond) : where(cond)
          else
            cache_key =
              _association_filter_cache_key(
                reflection: reflection,
                extra: :"bare_#{invert}",
              )

            cached_dataset(cache_key) do
              cond = _association_filter_dataset(reflection).exists
              invert ? exclude(cond) : where(cond)
            end
          end
        end

        def association_exclude(association_name, &block)
          association_filter(association_name, invert: true, &block)
        end

        private

        def _association_filter_dataset(reflection)
          cache_key = _association_filter_cache_key(reflection: reflection)

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

            local_keys  = Array(local_keys)
            remote_keys = Array(remote_keys)

            ds.where(
              remote_keys.
              zip(local_keys).
              map{|r,l| {r => l}}.
              inject{|a,b| Sequel.&(a, b)}
            ).select(1)
          end
        end

        def _association_filter_cache_key(reflection:, extra: nil)
          :"_association_filter_#{reflection[:model]}_#{reflection[:name]}_#{extra}"
        end
      end
    end
  end
end
