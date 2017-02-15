module Tome
  class Builder < Struct.new(:table, :klass, :block)
    def self.build! table, klass, &block
      new(table, klass, block).build!
    end

    attr_accessor :transformations

    def initialize(*)
      super
      self.transformations = []
      underscore_keys
      instance_eval &block if block.respond_to?(:call)
    end

    def build!
      table.hashes.map do |attributes|
        transformations.each { |transformation| transformation.call(attributes) }
        klass.create! attributes
      end
    end

    def transformation &block
      transformations << block
    end

    def field attribute
      transformation do |attributes|
        attributes[attribute.to_s] = yield(attributes.fetch(attribute.to_s, ""))
      end
    end

    def underscore_keys
      transformation do |attributes|
        new_attributes = attributes.inject({}) do |hash, (key, value)|
          hash.merge key.parameterize.underscore => value
        end
        attributes.replace new_attributes
      end
    end

    def file *keys
      keys.each do |key|
        field key do |path|
          File.open("features/support/fixtures/#{path}") if path.present?
        end
      end
    end

    def files *keys
      keys.each do |key|
        field key do |paths|
          paths.split(" ").map do |path|
            File.open("features/support/fixtures/#{path}")
          end
        end
      end
    end

    def has_many key, class_name=nil, delimiter: ", ", name_field: :name
      field key do |names|
        names.split(delimiter).map do |name|
          class_name.find_by!(name_field => name)
        end
      end
    end

    def has_one key, class_name=nil, name_field: :name
      field key do |name|
        class_name.find_by!(name_field => name)
      end
    end
    alias_method :belongs_to, :has_one
  end
end

