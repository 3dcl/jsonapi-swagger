require 'forwardable'
module Jsonapi
  module Swagger
    class JsonapiResource
      extend Forwardable

      def_delegators :@jr, :_attributes, :_relationships, :sortable_fields,
                          :creatable_fields, :updatable_fields, :filters, :mutable?

      def initialize(jr)
        @jr = jr
      end

      def attribute_type_info
        info = nil
        if(@jr.respond_to?(:resource_attribute_type_info))
          info = @jr.resource_attribute_type_info
        end

        info ||= @jr.const_get(:ATTRIBUTE_TYPE_INFO) if @jr.const_defined?(:ATTRIBUTE_TYPE_INFO)         
        
        (info || {}).with_indifferent_access
      end
      alias attributes _attributes
      alias relationships _relationships
    end
  end
end