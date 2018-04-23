require 'spec_helper'

describe Repor::Dimension::Bin do
  def new_dimension(dimension_params = {}, report_params = {}, opts = {})
    report_params[:dimensions] = { foo: dimension_params }
    Repor::Dimension::Bin.new(:foo,
      OpenStruct.new(params: report_params),
      opts
    )
  end

  def expect_error(&block)
    expect { yield }.to raise_error(Repor::InvalidParamsError)
  end

  describe 'param validation' do
    it 'yells unless :bin_count is numeric' do
      expect_error { new_dimension(bin_count: 'hey') }
      expect_error { new_dimension(bin_count: nil) }
      new_dimension(bin_count: 5)
      new_dimension(bin_count: 1.24)
    end
  end

  describe '#min/max' do
    it 'finds the extremes in filter_values' do
      dimension = new_dimension(only: [{ min: 1, max: 3 }, { min: -3 }, { min: 17, max: 40 }])
      expect(dimension.min).to eq -3
      expect(dimension.max).to eq 40
    end

    it 'falls back to the smallest value in the data' do
      dimension = Repor::Dimension::Bin.new(:likes,
        OpenStruct.new(records: Post, params: {}),
        expression: 'posts.likes'
      )
      expect(dimension.min).to be_nil
      expect(dimension.max).to be_nil
      create(:post, likes: 3)
      create(:post, likes: 10)
      create(:post, likes: 1)
      expect(dimension.min).to eq 1
      expect(dimension.max).to eq 10
    end
  end

  describe '#group_values' do
    it 'defaults to dividing the domain into bins of bin_width' do
      dimension = new_dimension(only: { min: 0, max: 3 })
      allow(dimension).to receive(:bin_width).and_return(1)
      allow(dimension).to receive(:data_contains_nil?).and_return(false)
      expect(dimension.group_values).to eq [
        { min: 0, max: 1 },
        { min: 1, max: 2 },
        { min: 2, max: 3 }
      ]
    end

    it 'is inclusive of max if data-driven' do
      dimension = new_dimension(only: { min: 0 })
      allow(dimension.report).to receive(:records).and_return(Post)
      allow(dimension).to receive(:expression).and_return('posts.likes')
      allow(dimension).to receive(:bin_width).and_return(1)
      create(:post, likes: 2)
      expect(dimension.group_values).to eq [
        { min: 0, max: 1 },
        { min: 1, max: 2 },
        { min: 2, max: 3 }
      ]
    end

    it 'can be customized' do
      dimension = new_dimension(bins: { min: 0, max: 1 })
      expect(dimension.group_values).to eq [{ min: 0, max: 1 }]
    end
  end
end
