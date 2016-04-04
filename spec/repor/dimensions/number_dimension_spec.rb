require 'spec_helper'

describe Repor::Dimensions::NumberDimension do
  def new_dimension(dimension_params = {}, report_params = {}, opts = {})
    report_params[:dimensions] = { foo: dimension_params }
    Repor::Dimensions::NumberDimension.new(
      :foo,
      OpenStruct.new(params: report_params),
      opts
    )
  end

  def expect_error(&block)
    expect { yield }.to raise_error(Repor::InvalidParamsError)
  end

  describe 'param validation' do
    it 'yells unless :bin_width is numeric' do
      expect_error { new_dimension(bin_width: '') }
      expect_error { new_dimension(bin_width: '49er') }
      expect_error { new_dimension(bin_width: { seconds: 1 }) }
      expect(new_dimension(bin_width: 10.5).bin_width).to eq 10.5
      expect(new_dimension(bin_width: '10').bin_width).to eq 10.0
    end
  end

  describe '#bin_width' do
    it 'reads from params' do
      dimension = new_dimension(bin_width: 7)
      expect(dimension.bin_width).to eq 7
    end

    it 'can divide the domain into :bin_count bins' do
      dimension = new_dimension(bin_count: 5, only: { min: 0, max: 5 })
      expect(dimension.bin_width).to eq 1
      expect(dimension.group_values).to eq [
        { min: 0, max: 1 },
        { min: 1, max: 2 },
        { min: 2, max: 3 },
        { min: 3, max: 4 },
        { min: 4, max: 5 }
      ]
    end

    it 'defaults to 10 equal bins' do
      dimension = new_dimension(only: { min: 0, max: 5 })
      expect(dimension.bin_width).to eq 0.5
    end
  end
end
