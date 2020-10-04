module ActiveReporter
  class << self
    def database_type
      @database_type ||= case database_adapter
      when /postgres/ then :postgres
      when /mysql/ then :mysql
      when /sqlite/ then :sqlite
      else
        raise "unsupported database #{database_adapter}"
      end
    end

    def numeric?(value)
      value.is_a?(Numeric) || value.is_a?(String) && value =~ /\A\d+(?:\.\d+)?\z/
    end

    private

    def database_adapter
      ActiveRecord::Base.connection_config[:adapter]
    end
  end
end

require 'deeply_enumerable'
Dir.glob(File.join(__dir__, 'active_reporter', '*/')).each { |file| require file.chomp('/') }
