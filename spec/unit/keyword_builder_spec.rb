# frozen_string_literal: true

require 'keyword_builder'
require 'byebug'

require_relative '../spec_helper'

RSpec.describe 'KeywordBuilder' do
  describe 'with a simple struct' do
    Record = Struct.new(:a, :b, :c) do
      def initialize(a:, b:, c:)
        super(a, b, c)
      end
    end

    let(:builder) { KeywordBuilder.create(Record) }

    it 'builds a record with the builder' do
      result = builder.build! do
        a 1
        b 2
        c 3
      end

      expect(result).to have_attributes(a: 1, b: 2, c: 3)
    end

    it 'builds a record combining arguments' do
      result = builder.build!(b: 2) do
        a 1
        c 3
      end

      expect(result).to have_attributes(a: 1, b: 2, c: 3)
    end

    it 'rejects arguments colliding with builder' do
      expect {
        builder.build!(a: 1, b: 2, c: 3) { a 1 }
      }.to raise_error(KeywordBuilder::BuilderError)
    end

    it 'rejects repeated arguments' do
      expect {
        builder.build!(a: 1, b: 2) do
          c 2
          c 3
        end
      }.to raise_error(KeywordBuilder::BuilderError)
    end

    it 'requires an argument' do
      expect {
        builder.build!(a: 1, b: 2) { c }
      }.to raise_error(ArgumentError, /Wrong number of arguments/)
    end

    it 'requires only one argument' do
      expect {
        builder.build!(a: 1, b: 2) { c(1, 2, 3) }
      }.to raise_error(ArgumentError, /Wrong number of arguments/)
    end

    it 'rejects unknown arguments' do
      expect {
        builder.build! { q 0 }
      }.to raise_error(NoMethodError)
    end

    it 'marks non-wildcard builders' do
      expect(builder).not_to be_wildcard
    end

    context 'with wildcard arguments' do
      WildcardRecord = Struct.new(:a, :b) do
        def initialize(**rest)
          super(rest.delete(:a), rest)
        end
      end

      let(:builder) { KeywordBuilder.create(WildcardRecord) }

      it 'marks wildcard builders' do
        expect(builder).to be_wildcard
      end

      it 'passes wildcard arguments' do
        result = builder.build! do
          a 1
          b 2
          c 3
        end
        expect(result).to have_attributes(a: 1, b: { b: 2, c: 3 })
      end
    end
  end
end
