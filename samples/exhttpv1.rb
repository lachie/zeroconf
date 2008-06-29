#!/usr/local/bin/ruby18 -w
# Author: Sam Roberts <sroberts@uniserve.com>
# Licence: this file is placed in the public domain

require 'net/http'
require 'net/dns/resolv-mdns'

mdns = Resolv::MDNS.default

mdns.each_resource('_http._tcp.local', Resolv::DNS::Resource::IN::PTR) do |rrhttp|
  service = rrhttp.name
  host = nil
  port = nil
  path = '/'

  rrsrv = mdns.getresource(rrhttp.name, Resolv::DNS::Resource::IN::SRV)
  host, port = rrsrv.target.to_s, rrsrv.port
  rrtxt = mdns.getresource(rrhttp.name, Resolv::DNS::Resource::IN::TXT)
  if  rrtxt.data =~ /path=(.*)/
    path = $1
  end

  http = Net::HTTP.new(host, port)

  headers = http.head(path)

  puts "#{service[0]} on #{host}:#{port}#{path} was last-modified #{headers['last-modified']}"
end

