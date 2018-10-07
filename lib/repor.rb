module Repor
  def self.database_type
    database_adapter_name = ActiveRecord::Base.connection_config[:adapter]
    case database_adapter_name
    when /postgres/ then :postgres
    when /mysql/ then :mysql
    when /sqlite/ then :sqlite
    else
      raise "unsupported database #{database_adapter_name}"
    end
  end

  def self.numeric?(value)
    value.is_a?(Numeric) || value.is_a?(String) && value =~ /\A\d+(?:\.\d+)?\z/
  end
end

require 'deeply_enumerable'
Dir.glob(File.join(__dir__, 'repor', '*/')).each { |file| require file.chomp('/') }
