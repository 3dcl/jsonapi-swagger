# JSONAPI Swagger

Generate JSONAPI Swagger Doc.

[![Gem Version](https://img.shields.io/gem/v/jsonapi-swagger.svg)](https://rubygems.org/gems/jsonapi-swagger)
[![GitHub license](https://img.shields.io/github/license/superiorlu/jsonapi-swagger.svg)](https://github.com/superiorlu/jsonapi-swagger/blob/master/LICENSE)

[![jsonapi-swagger-4-2-9.gif](https://i.loli.net/2019/05/05/5ccebf5e782b7.gif)](https://i.loli.net/2019/05/05/5ccebf5e782b7.gif)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jsonapi-swagger'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jsonapi-swagger

## Usage

 1. config jsonapi swagger
```rb
# config/initializers/swagger.rb
Jsonapi::Swagger.config do |config|
  config.use_rswag = false
  config.version = '3.0.0'
  config.info = { title: 'API V1', version: 'V1'}
  config.file_path = 'v1/swagger.json'
end
```


2. generate swagger.json

```sh
# gen swagger/v1/swagger.json
bundle exec rails generate jsonapi:swagger User # UserResource < JSONAPI::Resource
```

3. additional

 use `rswag`, have to run

```sh
# gen swagger/v1/swagger.json
 bundle exec rails rswag:specs:swaggerize
```


4. Adjust swagger_helper.rb

It must include the generated schema files into the openapi / swagger file to referenced

```ruby
require "rails_helper"

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.to_s + "/swagger"



  common_types = Rails.root.join("config", "schemas", "openapi", "types", "common_json_api.schema.json")
  schema_components = JSON.parse(File.read(common_types)).dig("components", "schemas") || {}
  Dir.glob(Rails.root.join("config", "schemas", "openapi", "types", "**.schema.json")).each do |file|

    resource_name = file.split("/").last.split(".").first
    # do not double include the jsonapi types
    next if(resource_name == "common_json_api")

    schema = JSON.parse(File.read(file))
    schema_components[resource_name] = schema
  end

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:to_swagger' rake task, the complete Swagger will
  # be generated at the provided relative path under swagger_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a swagger_doc tag to the
  # the root example_group in your specs, e.g. describe '...', swagger_doc: 'v2/swagger.json'
  config.openapi_specs = {
    "v1/swagger.json" => {
      openapi: "3.0.0",
      info: {
        title: "API V1",
        version: "v1"
      },
      components: {
        schemas: schema_components
      },
      paths: {
      },

    servers: [
      {
        "url": "{protocol}://{host}/api",
        "variables": {
          "protocol": {
            "enum": ["https"],
            "default": "https"
          },
          "host": {
            "default": "www.example.com"
          }
        }
      }
    ]}
  }
end
```

## Customization 

### Overriding Types in Resource Classes

If your resource adds attributes that do not map directly to a database column there are in general no type information attached. As a solution to generate matching json schemas and running specs a const can be defined on your resource class providing a hash with more type info.

*Example for JSONAPI REsources*

```
class ExampleResource < JSONAPI::Resource

attributes :subscribed,
  :values

  ATTRIBUTE_TYPE_INFO = {
    subscribed: { type: :boolean},
    values: {type: :array, 
      items_type: :float, 
      comment: 'Explanatory comment, overrides stored database column comment'
    }
  }

  def subscribed
    current_user = context[:current_user]
    return nil if current_user.nil?

    @model.subscribed_by?(current_user)
  end

  def values
    # an array of numbers
    @model.values
  end
end
```

### Before, After and POST / PATCH data

As it cannot be forseen what is necessary to create a certain resource, there are several methods to adjust the generated code to provide an individual setup for models and to accommodate your authentication / authorization framework

The generated code for before action ```before { ... }```, after action ```after { ... } ``` and data definition ```let(:data){ ... }``` are created using corresponding templates:
* ```swagger_base.rb.erb``` - optional base data and defintions to put on top of each generated spec
* ```swagger_before.rb.erb```
* ```swagger_after.rb.erb```
* ```swagger_data.rb.erb```

It is possible to override them by creating corresponding custom files in lib/generators/jsonapi/swagger/templates

In case you need custom code per resource, create a custom file for resource that preceedes the general templates

* ```swagger_before_{resources_name}.rb.erb```
* ```swagger_after_{resources_name}.rb.erb```
* ```swagger_data_{resources_name}.rb.erb```

## RoadMap

- [x] immutable resources
- [x] filter/sort resources
- [x] mutable resources
- [x] generate swagger.json without rswag

## Resource

- [JSONAPI](https://jsonapi.org/)
- [JSONAPI::Resources](http://jsonapi-resources.com/)
- [Rswag](https://github.com/domaindrivendev/rswag)

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/superiorlu/jsonapi-swagger.
