require 'spec_helper'

describe Repor::Dimensions::BinDimension::Bin do
  describe '.from_hash' do
    it 'builds a bin from a hash or nil' do
      bin = described_class.from_hash(min: 1, max: 2)
      expect(bin.min).to eq 1
      expect(bin.max).to eq 2

      bin = described_class.from_hash(nil)
      expect(bin.min).to eq nil
      expect(bin.max).to eq nil
    end
  end

  describe '.from_sql' do
    it 'builds a bin from a bin text string' do
      bin = described_class.from_sql("1,2")
      expect(bin.min).to eq '1'
      expect(bin.max).to eq '2'

      bin = described_class.from_sql("1,")
      expect(bin.min).to eq '1'
      expect(bin.max).to eq nil

      bin = described_class.from_sql(",2")
      expect(bin.min).to eq nil
      expect(bin.max).to eq '2'

      bin = described_class.from_sql(",")
      expect(bin.min).to eq nil
      expect(bin.max).to eq nil
    end
  end

  describe '#contains_sql' do
    it 'returns SQL checking if expr is in the bin' do
      bin = described_class.new(1, 2)
      expect(bin.contains_sql('foo')).to eq "(foo >= 1 AND foo < 2)"

      bin = described_class.new(1, nil)
      expect(bin.contains_sql('foo')).to eq "foo >= 1"

      bin = described_class.new(nil, 2)
      expect(bin.contains_sql('foo')).to eq "foo < 2"

      bin = described_class.new(nil, nil)
      expect(bin.contains_sql('foo')).to eq "foo IS NULL"
    end
  end

  describe '#to_json' do
    it 'reexpresses the bin as a hash' do
      bin = described_class.new(1, 2)
      json = { a: bin }.to_json
      expect(JSON.parse(json)).to eq('a' => { 'min' => 1, 'max' => 2 })
    end
  end

  describe 'hashing' do
    it 'works with hashes' do
      bin1 = described_class.new(1, 2)
      bin2 = described_class.new(1, 2)
      bin3 = { min: 1, max: 2 }

      h = { bin3 => 'foo' }
      expect(h[bin1]).to eq 'foo'
      expect(h[bin2]).to eq 'foo'
      expect(h[bin3]).to eq 'foo'
    end

    it 'works with nil' do
      bin1 = described_class.new(nil, nil)
      bin2 = described_class.new(nil, nil)
      bin3 = nil

      h = { bin3 => 'foo' }
      expect(h[bin1]).to eq 'foo'
      expect(h[bin2]).to eq 'foo'
      expect(h[bin3]).to eq 'foo'
    end
  end
end
