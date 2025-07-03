require 'forwardable'
module Jsonapi
  module Swagger
    class SerializableResource
      extend Forwardable

      def_delegators :@sr, :type_val, :attribute_blocks, :relationship_blocks, :link_blocks

      def initialize(sr)
        @sr = sr
      end

      alias attributes attribute_blocks

      def attribute_type_info
        {}.with_indifferent_access
      end

      def relationships
        {}.tap do |relations|
          relationship_blocks.each do |rel, _block|
            relations[rel] = OpenStruct.new(class_name: rel.to_s)
          end
        end
      end

      # TODO: from jsonapi serializable resource
      def sortable_fields
        []
      end

      def creatable_fields
        []
      end

      def updatable_fields
        []
      end

      def filters
        []
      end

      def mutable?
        false
      end

      # TODO: from jsonapi resource, get the modl classs. using the resource
      def model_klass
        nil
      end
    end
  end
end
