require 'zeroconf/common'

module Zeroconf
  module Pure
    require File.expand_path("#{File.dirname(__FILE__)}/../net/dns/mdns-sd")
    ::DNSSD = Net::DNS::MDNSSD
    
    unless defined?(DNSSD::TextRecord)
      class ::DNSSD::TextRecord < Hash
      end
    end
  end
end