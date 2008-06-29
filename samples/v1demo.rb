#!/usr/local/bin/ruby18 -w
#
# Example code to use the multicast library
# (c) 2005 Ben Giddings
# License: Ruby's License

# Include local dir
$: << File.dirname($0)

require 'net/dns/resolv-mdns'
require 'pp'

# default to browsing
operation = ARGV[0] || 'browse'

resolver = Resolv::MDNS.new
resolver.lazy_initialize

def usage
  $stderr.puts <<-EOF
Usage: #{$0} [browse|discover|resolve|lookup] [service_str]

Use "browse" to find names offering the service requested.

Examples:
  zsh% #{$0} browse
  Searching for _http._tcp.local services
  Matching entries in _http._tcp.local
  Cool Webserver

  zsh% #{$0} browse http
  Searching for _http._tcp.local services
  Matching entries in _http._tcp.local
  Cool Webserver

  zsh% #{$0} browse _http._tcp.local
  Searching for _http._tcp.local services
  Matching entries in _http._tcp.local
  Cool Webserver

  zsh% #{$0} browse _telnet._tcp.local
  Searching for _telnet._tcp.local services
  Matching entries in _telnet._tcp.local
  Embedded Device (MAC addr: 00:01:02:03:04:05)

By default 'browse' looks for _http._tcp.local services/
If the only parameter supplied is a protocol, it looks for 
local tcp services of that protocol

Use "resolve" to look up the dns name, port and ip address of a device

  zsh% #{$0} resolve 'Cool Webserver'
  Searching for Cool Webserver._http._tcp.local instance
  Cool Webserver._http._tcp.local is
  coolweb.local:80 at IP 192.168.0.12

  zsh% #{$0} resolve 'Cool Webserver._http._tcp.local'
  Searching for Cool Webserver._http._tcp.local instance
  Cool Webserver._http._tcp.local is
  coolweb.local:80 at IP 192.168.0.12

  zsh% #{$0} resolve 'Embedded Device (MAC addr: 00:01:02:03:04:05)._telnet._tcp.local'
  Searching for Embedded Device (MAC addr: 00:01:02:03:04:05)._telnet._tcp.local instance
  Embedded Device (MAC addr: 00:01:02:03:04:05)._telnet._tcp.local is
  emb000102030405.local:23 at IP 192.168.0.93

By default 'resolve' will append _http._tcp.local if it is missing

  EOF
end

case (operation.downcase)
when 'browse', 'discover'
  #
  # To browse / discover services, use a ptr lookup on the service protocol
  # A typical call might be
  # resolver.getresources('_http._tcp.local', Resolv::DNS::Resource::IN::PTR)
  #

  # default to browsing for http hosts
  service_str = ARGV[1] || 'http'

  # prepend an underscore if necessary
  # p service_str

  if ?_ != service_str[0]
    puts "prepending underscore to #{service_str}"
    service_str = '_' + service_str
  end

  # append a ._tcp.local if necessary (assume tcp and local)
  if service_str.index('.').nil?
    puts "No dot found in service name, appending ._tcp.local"
    service_str += '._tcp.local'
  end

  puts "Searching for #{service_str} services"

  entries = resolver.getresources(service_str, Resolv::DNS::Resource::IN::PTR)

  # p entries

  puts "Matching entries in #{service_str}"
  entries.each {
    |entry|
    # p entry
    # I think this will always match but just in case...
    friendly_name_regexp = /(.*?)\.#{service_str}/

    match = friendly_name_regexp.match(entry.name.to_s)
    if match
      puts match[1]
    else
      puts entry.name
    end
  }
when 'resolve', 'lookup'
  #
  # To resolve / lookup services, first use a SRV lookup to lookup the service
  # details, then extract the hostname from the result.  Using this hostname,
  # lookup the A record to find the IP address.
  #

  service_str = ARGV[1]
  if service_str.nil?
    $stderr.puts("Service string required for resolve / lookup")
    usage()
    exit(1)
  end

  # append a ._http._tcp.local if necessary (assume http, tcp and local)
  if service_str.index('.').nil?
    puts "No dot found in service name, appending ._http._tcp.local"
    service_str += '._http._tcp.local'

  end

  puts "Searching for #{service_str} instance"
  entries = resolver.getresources(service_str, Resolv::DNS::Resource::IN::SRV)

  if 0 == entries.size
    puts "Unable to find #{service_str}"
    exit(0)
  end

  entry = entries[0]
  # puts "Found match at #{entry.target}, port #{entry.port}"

  hostname = entry.target
  port = entry.port
  entries = resolver.getresources(hostname, Resolv::DNS::Resource::IN::A)

  if 0 == entries.size
    puts "Unable to resolve #{hostname}"
    exit(1)
  end

  entry = entries[0]
  # p entry
  # p entry.address
  puts "#{service_str} is\n#{hostname}:#{port} at IP #{entry.address.to_s}"

else
  $stderr.puts("unknown operation #{operation.inspect}")
  usage()
  exit(1)
end
