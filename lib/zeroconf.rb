module Zeroconf
  require 'zeroconf/version'

  if VARIANT_BINARY
    require 'zeroconf/ext'
  else
    begin
      require 'zeroconf/ext'
    rescue LoadError
      require 'zeroconf/pure'
    end
  end

  ZEROCONF_LOADED = true
end