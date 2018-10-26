# frozen_string_literal: true

# Abstract builder interface for types with keyword argument constructors.
class KeywordBuilder
  class << self
    def create(clazz, constructor: :new)
      keywords, wildcard = parse_constructor_parameters(clazz, constructor)

      Class.new(self) do
        define_singleton_method(:clazz) { clazz }
        define_singleton_method(:constructor) { constructor }
        define_singleton_method(:keywords) { keywords }
        define_singleton_method(:wildcard?) { wildcard }
        keywords.each do |keyword|
          define_method(keyword) { |*args, &block| _set_attribute(keyword, *args, &block) }
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

  def _set_attribute(attr, *args, &block)
    if attrs.has_key?(attr)
      raise RuntimeError.new("Invalid builder state: #{attr} already provided")
    end

    value =
      if block_given?
        raise ArgumentError.new('Cannot provide both immediate and block value') unless args.blank?

        block
      elsif args.size == 1
        args[0]
      else
        raise ArgumentError.new('Wrong number of arguments: expected 1 or block')
      end

    attrs[attr] = value
  end

  def method_missing(attr, *args, &block)
    if self.class.wildcard?
      _set_attribute(attr, *args, &block)
    else
      super
    end
  end

  def respond_to_missing?(attr, _include_all = false)
    self.class.wildcard? || super
  end
end
