module Jsonapi
  class SwaggerGenerator < Rails::Generators::NamedBase
    desc 'Create a JSONAPI Swagger.'
    source_root File.expand_path('templates', __dir__)
    def create_swagger_file
      results = []
      if Jsonapi::Swagger.use_rswag

        puts "Generating Swagger spec for #{model_class_name} using Rswag ..."
        results << template('swagger.rb.erb', spec_file)
        results << template('swagger_types.schema.json.erb', spec_types_file)
        results << template('common_types_jsonapi.schema.json.erb', common_types_file)

      else
        results << template('swagger.json.erb', json_file)
      end
      results
    end

    protected

    def doc
      @doc ||= swagger_json.parse_doc
    end

    def spec_file
      @spec_file ||= File.join(
        'spec/requests',
        class_path,
        spec_file_name
      )
    end

    def spec_types_file
      @spec_schema_type_file ||= File.join(
        'config/schemas/openapi/types',
        class_path,
        schema_type_file_name
      )
    end

    def schema_file_for_resource_exstists?(the_resource_name)
      file = schema_filename_for_resource(the_resource_name)
      File.exist?(file)
    end

    def schema_file_for_resource(the_resource_name = resource_name)
      @schema_file_for_resource ||= schema_filename_for_resource(the_resource_name)
    end

    def schema_filename_for_resource(resource_name)
      File.join(
        'config/schemas/openapi/types',
        class_path,
        "#{resource_name.underscore}.schema.json"
      )
    end

    def common_types_file
      @common_types_file ||= File.join(
        'config/schemas/openapi/types',
        'common_json_api.schema.json'
      )
    end

    def spec_data; end

    def spec_after
      ''
    end

    def json_file
      @json_file ||= File.join(
        'swagger',
        class_path,
        swagger_file_path
      )
    end

    def swagger_version
      Jsonapi::Swagger.version
    end

    def swagger_info
      JSON.pretty_generate(Jsonapi::Swagger.info)
    end

    def swagger_base_path
      Jsonapi::Swagger.base_path
    end

    def swagger_file_path
      Jsonapi::Swagger.file_path
    end

    def swagger_json
      @swagger_json ||= Jsonapi::Swagger::Json.new(json_file)
    end

    def spec_file_name
      "#{file_name.downcase.pluralize}_spec.rb"
    end

    def schema_type_file_name
      "#{file_name.downcase.pluralize}.schema.json"
    end

    def model_name
      file_name.downcase.singularize
    end

    def resources_name
      model_class_name.demodulize.pluralize
    end

    def resource_type_name
      resources_name.underscore
    end

    def route_resources
      # use unscoped routes to handle module scoped model class names. e.g. Admin::User
      class_name_to_resource_name(resources_name)
    end

    def model_class_name
      (class_path + [file_name]).map!(&:camelize).join('::')
    end

    def sortable_fields_desc
      t(:sortable_fields) + ': (-)' + sortable_fields.join(',')
    end

    def ori_sortable_fields_desc
      tt(:sortable_fields) + ': (-)' + sortable_fields.join(',')
    end

    def model_klass
      return @model_klass if @model_klass

      @model_klass ||= model_class_name.safe_constantize

      return @model_klass if @model_klass.present?

      @model_klass = resource_klass&.model_klass if @model_klass.blank? && resource_klass.present?

      if @model_klass.blank?
        raise Jsonapi::Swagger::Error, "Model class '#{model_class_name}' not found! " \
                                        'Please check if the model class exists and is loaded.'
      end
      @model_klass
    end

    def resource_klass
      @resource_klass ||= Jsonapi::Swagger::Resource.with(model_class_name)
    end

    def attributes
      resource_klass.attributes.except(:id)
    end

    def relationships
      resource_klass.relationships
    end

    def relationship_resource_names
      relationships.values.map { |relation| relation_resource_name(relation) }
    end

    def relationship_resource_names_uniq
      relationships.values.map { |relation| relation_resource_name(relation) }.uniq
    end

    def relationship_table_names
      relationships.values.map { |relation| relation_resource_name(relation) }
    end

    def uniq_relationship_table_names(exclude: [])
      relationship_table_names.uniq.reject { |name| exclude.include?(name) }
    end

    def sortable_fields
      resource_klass.sortable_fields
    end

    def creatable_fields
      resource_klass.creatable_fields - relationships.keys
    end

    def updatable_fields
      resource_klass.updatable_fields - relationships.keys
    end

    def filters
      resource_klass.filters
    end

    # Returns the list of allowed values (enum) for a given attribute if defined.
    #
    # @param attribute [String, Symbol] The name of the attribute to check for enum values.
    # @return [Array, nil] The array of allowed values if the attribute has an enum defined, otherwise nil.
    def filter_value_enum(attribute_name)
      type_info = resource_klass.attribute_type_info[attribute_name.to_sym]
      type_info[:enum] if type_info.is_a?(Hash) && type_info[:enum].present?
    end

    def mutable?
      resource_klass.mutable?
    end

    def attribute_default
      Jsonapi::Swagger.attribute_default
    end

    def transform_method
      @transform_method ||= resource_klass.transform_method if resource_klass.respond_to?(:transform_method)
    end

    def columns_with_comment(need_encoding: true)
      type_info = resource_klass.attribute_type_info

      @columns_with_comment ||= {}.tap do |clos|
        clos.default_proc = proc do |h, k|
          t = swagger_type(nil, k.to_s)
          attr_descr = attribute_default.merge(type: t, is_array: t == :array)
          if t == :array
            attr_descr[:items_type] = array_items_type(k, nil)
            items_properties = type_info&.dig(k.to_sym, :items_properties)
            attr_descr[:items_properties] = items_properties if items_properties
          end
          comment = column_comment(nil, k)
          attr_descr[:comment] = comment if comment
          enum_values = column_value_enum(nil, k)
          attr_descr[:enum] = column_value_enum(nil, k) if enum_values.present?

          attr_descr[:properties] = column_value_properties(nil, k) if t == :object

          h[k] = attr_descr
        end
        model_klass.columns.each do |col|
          col_name = transform_method ? col.name.send(transform_method) : col.name

          is_array = col.respond_to?(:array) ? col.array : false
          clos[col_name.to_sym] = {
            type: swagger_type(col, col_name),
            items_type: array_items_type(col_name, col),
            is_array: is_array,
            nullable: col.null,
            comment: column_comment(col, col_name),
            enum: column_value_enum(col, col_name)
          }

          format = swagger_format(col)
          clos[col_name.to_sym][:format] = format unless format.nil?
          if clos[col_name.to_sym][:properties] == :object
            clos[col_name.to_sym][:properties] = column_value_properties(col, col_name)
          end

          clos[col_name.to_sym][:comment] = safe_encode(col.comment) if need_encoding
        end
        if model_klass.respond_to? :translation_class
          model_klass.translation_class.columns.each do |col|
            next unless model_klass.translated_attribute_names.include? col.name.to_sym

            clos[col.name.to_sym] =
              { type: swagger_type(col, col.name), items_type: col.type, is_array: col.array, nullable: col.null,
                comment: col.comment }
            clos[col.name.to_sym][:comment] = safe_encode(col.comment) if need_encoding
          end
        end
      end
    end

    def column_comment(_col, col_name)
      type_info = resource_klass.attribute_type_info[col_name.to_sym]
      (resource_klass.attribute_type_info[col_name.to_sym]&.[](:comment) if type_info.is_a?(Hash))
    end

    def swagger_type(column)
      return 'array' if column.respond_to?(:array) && column.array

      comment ||= col&.comment
      comment
    end

    def column_value_properties(_col, col_name)
      lookup_res = resource_klass.attribute_type_info[col_name.to_sym]
      lookup_res[:properties] if lookup_res.is_a?(Hash)
    end

    def column_value_enum(_col, col_name)
      type_info = resource_klass.attribute_type_info[col_name.to_sym]

      resource_klass.attribute_type_info[col_name.to_sym]&.[](:enum) if type_info.is_a?(Hash)
    end

    def swagger_type(column, name = nil)
      name ||= column&.name
      return :array if column&.array

      type = swagger_type_from_column_type(column&.type)

      type_info = resource_klass.attribute_type_info

      if type_info[name.to_sym].present?
        t = type_info[name.to_sym]
        return t[:type] if t.is_a?(Hash)

        t
      elsif !type.nil?
        type
      else
        :string
      end
    end

    # derives the swagger attribute type from AR database column type, also accepts json schema types
    def swagger_type_from_column_type(type)
      case type&.to_sym
      when :bigint, :integer, :primary_key then 'integer'
      when :boolean then 'boolean'
      when :real, :number, :float, :decimal, :bigdecimal then 'number'
      when :object, :jsonb, :json then 'object'
      end
    end

    # derives the items type of an array type.
    def array_items_type(attribute, col = nil)
      items_type = col.type if col

      type_info = resource_klass.attribute_type_info

      if type_info && type_info&.[](attribute.to_sym).is_a?(Hash) && type_info&.[](attribute.to_sym)&.[](:items_type)
        items_type = type_info&.[](attribute.to_sym)&.[](:items_type)
        items_type = swagger_type_from_column_type(items_type) if items_type
      end

      return :string if items_type.blank?

      items_type.to_sym
    end

    def swagger_format(column)
      case column.type
      when :date then 'date'
      when :datetime then 'datetime'
      when :float then 'double'
      end
    end

    def class_name_to_resource_name(class_name)
      class_name.tableize.split('/').last
    end

    def relation_resource_name(relation)
      return class_name_to_resource_name(relation.class_name) if relation.respond_to?(:class_name)

      relation.name if relation.respond_to?(:name)
    end

    alias relation_table_name relation_resource_name

    def t(key, options = {})
      content = tt(key, options)
      safe_encode(content)
    end

    def tt(key, options = {})
      options[:scope] = :jsonapi_swagger
      options[:default] = key.to_s.humanize
      I18n.t(key, **options)
    end

    def safe_encode(content)
      content&.force_encoding('ASCII-8BIT')
    end
  end
end
