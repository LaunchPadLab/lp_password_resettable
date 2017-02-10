module LpResettable
  def self.config
    @config ||= LpResettable::Config.new
    if block_given?
      yield @config
    else
      @config
    end
  end
end

require 'lp_resettable/config'
require 'lp_resettable/error'
require 'lp_resettable/model'
require 'lp_resettable/version'
