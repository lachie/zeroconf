#!/usr/local/bin/ruby18 -w
# Author: Sam Roberts <sroberts@uniserve.com>
# Licence: this file is placed in the public domain

require 'net/http'
require 'thread'
require 'pp'

# For MDNSSD
require 'net/dns/mdns-sd'

# To make Resolv aware of mDNS
require 'net/dns/resolv-mdns'

# To make TCPSocket use Resolv, not the C library resolver.
require 'net/dns/resolv-replace'

# Use a short name.
DNSSD = Net::DNS::MDNSSD

# Sync stdout, and don't write to console from multiple threads.
$stdout.sync
$lock = Mutex.new

# Be quiet.
debug = false

DNSSD.browse('_http._tcp') do |b|
  $lock.synchronize { pp b } if debug
  DNSSD.resolve(b.name, b.type) do |r|
    $lock.synchronize { pp r } if debug
    begin
      http = Net::HTTP.new(r.target, r.port)

      path = r.text_record['path'] || '/'

      headers = http.head(path)

      $lock.synchronize do
        puts "#{r.name.inspect} on #{r.target}:#{r.port}#{path} using server #{headers['server']}"
      end
    rescue
      $lock.synchronize { puts $!; puts $!.backtrace }
    end
  end
end

# Hit enter when you think that's all.
STDIN.gets

