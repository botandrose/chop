module Chop
  class Builder < Struct.new(:table, :klass, :block)
    def self.build! table, klass, &block
      new(table, klass, block).build!
    end

    attr_accessor :transformations

    def initialize(*)
      super
      self.transformations = []
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

    def field attribute, default: ""
      transformation do |attributes|
        attributes[attribute.to_s] = yield(attributes.fetch(attribute.to_s, default))
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

    def file *keys, path: "features/support/fixtures"
      keys.each do |key|
        field key do |file|
          File.open(File.join(path, file)) if file.present?
        end
      end
    end

    def files *keys, path: "features/support/fixtures", delimiter: " "
      keys.each do |key|
        field key do |paths|
          paths.split(delimiter).map do |file|
            File.open(File.join(path, file))
          end
        end
      end
    end

    def has_many key, klass=nil, delimiter: ", ", name_field: :name
      field key do |names|
        names.split(delimiter).map do |name|
          klass.find_by!(name_field => name)
        end
      end
    end

    def has_one key, klass=nil, name_field: :name
      field key do |name|
        klass.find_by!(name_field => name)
      end
    end
    alias_method :belongs_to, :has_one
  end
end

