# frozen_string_literal: true
require 'set'

# Abstract builder interface for types with keyword argument constructors.
class KeywordBuilder
  class BuilderError < ArgumentError; end

  class << self
    def create(clazz, constructor: :new)
      keywords, wildcard = parse_constructor_parameters(clazz, constructor)

      Class.new(self) do
        define_singleton_method(:clazz) { clazz }
        define_singleton_method(:constructor) { constructor }
        define_singleton_method(:keywords) { keywords }
        define_singleton_method(:wildcard?) { wildcard }
        keywords.each do |keyword|
          define_method(keyword) { |*args, **kwargs, &block| _set_attribute(keyword, *args, **kwargs, &block) }
        end
      end
    end

    def valid_keyword?(param)
      wildcard? || keywords.include?(param)
    end

    def build!(**initial_attrs, &block)
      builder = self.new(initial_attrs)
      builder.instance_eval(&block) if block_given?
      clazz.public_send(constructor, **builder.attrs)
    end

    private

    def parse_constructor_parameters(clazz, constructor)
      parameters =
        if constructor == :new
          clazz.instance_method(:initialize).parameters
        else
          clazz.method(constructor).parameters
        end

      keywords = Set.new
      wildcard = false

      parameters.each do |type, name|
        case type
        when :opt, :rest
          next
        when :key, :keyreq
          keywords << name
        when :keyrest
          wildcard = true
        else
          raise ArgumentError.new("Invalid builder method, contains required non-keyword parameter #{name}")
        end
      end

      [keywords.freeze, wildcard]
    end
  end

  attr_reader :attrs

  def initialize(initial_attrs)
    @attrs = initial_attrs.dup
  end

  def _set_attribute(attr, *args, **kwargs, &block)
    if attrs.has_key?(attr)
      raise BuilderError.new("Invalid builder state: #{attr} already provided")
    end

    if kwargs.empty?
      value = args.dup

      value << block if block_given?

      if value.empty?
        raise ArgumentError.new('Wrong number of arguments: expected at least one argument or block')
      end

      value = value[0] if value.size == 1
    else
      unless args.empty? && block.nil?
        raise ArgumentError.new('Invalid arguments: cannot provide both keyword and positional arguments')
      end

      value = kwargs.dup
    end

    attrs[attr] = value
  end

  def method_missing(attr, *args, **kwargs, &block)
    if self.class.wildcard?
      _set_attribute(attr, *args, **kwargs, &block)
    else
      super
    end
  end

  def respond_to_missing?(attr, _include_all = false)
    self.class.wildcard? || super
  end
end
