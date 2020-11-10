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
  config.version = '2.0'
  config.info = { title: 'API V1', version: 'V1'}
  config.file_path = 'v1/swagger.json'
end
```

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
