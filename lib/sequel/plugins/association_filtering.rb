# frozen_string_literal: true

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
        COUNT_STAR = Sequel.virtual_row{count.function.*}

        def association_filter(
          association_name,
          invert: false,
          **extra
        )
          having_args = extra.slice(:at_least, :at_most, :exactly)

          case having_args.length
          when 0
            # No-op
          when 1
            having_arg   = having_args.keys[0]
            having_value = having_args.values[0]
            raise Error, ":#{having_arg} must be an Integer if present" unless having_value.is_a?(Integer)
          else
            raise Error, "cannot pass more than one of :at_least, :at_most, and :exactly"
          end

          reflection =
            model.association_reflections.fetch(association_name) do
              raise Error, "association #{association_name} not found on model #{model}"
            end

          ds = _association_filter_dataset(reflection, group_by_remote: !!having_arg)
          ds = yield(ds) if block_given?

          if having_arg
            ds =
              ds.having(
                case having_arg
                when :at_least then COUNT_STAR >= having_value
                when :at_most  then COUNT_STAR <= having_value
                when :exactly  then COUNT_STAR =~ having_value
                else raise Error, "Unexpected argument: #{having_arg.inspect}"
                end
              )
          end

          cond = ds.exists
          cond = Sequel.~(cond) if invert
          where(cond)
        end

        def association_exclude(association_name, &block)
          association_filter(association_name, invert: true, &block)
        end

        private

        def _association_filter_dataset(reflection, group_by_remote:)
          cache_key =
            _association_filter_cache_key(
              reflection: reflection,
              extra: (:group_by_remote if group_by_remote)
            )

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

            result =
              ds.where(
                remote_keys.
                zip(local_keys).
                map{|r,l| {r => l}}.
                inject{|a,b| Sequel.&(a, b)}
              ).select(1)

            if group_by_remote
              result.group_by(*remote_keys)
            else
              result
            end
          end
        end

        def _association_filter_cache_key(reflection:, extra: nil)
          :"_association_filter_#{reflection[:model]}_#{reflection[:name]}_#{extra}"
        end
      end
    end
  end
end
