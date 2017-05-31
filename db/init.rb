require 'oci8'

begin; require './db/config.rb'; rescue LoadError; end

module DB
  def self.connect(env = nil)
    OCI8.new('vileven', 'Chelsea11', '127.0.0.1/XE' )
  end
end
