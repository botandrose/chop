module Tome
  class Builder
    cattr_accessor(:builders) { Hash.new }

    def self.register klass, &block
      builder = Class.new(TableBuilder) do
        factory klass
        instance_eval &block
      end
      builders[klass] = builder
    end

    def self.build! table, klass, &block
      if block_given? and !builders[klass]
        register klass, &block
      end
      builders[klass].build!(table)
    end
  end

  class TableBuilder < Struct.new(:table)
    def build!
      table.hashes.map do |attributes|
        transformations.each { |transformation| transformation.call(attributes) }
        factory.create! attributes
      end
    end

    class_attribute :transformations, :factory_klass
    self.transformations = []

    def self.transformation &block
      transformations << block
    end

    def self.factory klass=nil
      if klass.nil?
        factory_klass || default_klass
      else
        self.factory_klass = klass
      end
    end

    def self.default_klass
      to_s.sub("Builder", "").constantize
    end

    def self.build! table
      new(table).build!
    end

    def factory
      self.class.factory
    end

    transformation do |attributes|
      new_attributes = attributes.inject({}) do |hash, (key, value)|
        hash.merge key.parameterize.underscore => value
      end
      attributes.replace new_attributes
    end

    def self.has_attached_file *keys
      keys.each do |key|
        key = key.to_s
        transformation do |attributes|
          if attributes[key].present?
            attributes[key] = File.open(Rails.root.join("features/support/fixtures/#{attributes[key]}"))
          end
        end
      end
    end
  end
end

