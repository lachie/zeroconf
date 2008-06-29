#!/usr/local/bin/ruby18 -w
# Author: Sam Roberts <sroberts@uniserve.com>
# Licence: this file is placed in the public domain

$:.unshift(File.dirname($0))

require 'getoptlong'

$stdout.sync = true
$stderr.sync = true

=begin
Apple's dns-sd options:

  mdns -E                  (Enumerate recommended registration domains)
  mdns -F                      (Enumerate recommended browsing domains)
  mdns -B        <Type> <Domain>         (Browse for service instances)
  mdns -L <Name> <Type> <Domain>           (Look up a service instance)
  mdns -R <Name> <Type> <Domain> <Port> [<TXT>...] (Register a service)
  mdns -P <Name> <Type> <Domain> <Port> <Host> <IP> [<TXT>...]  (Proxy)
  mdns -Q <FQDN> <rrtype> <rrclass> (Generic query for any record type)
=end

@debug = false
@log   = nil

@recursive = false
@domain = 'local'
@type = nil
@name = nil
@port = nil
@txt  = {}

@cmd = nil


# TODO - can I use introspection on class names to determine all supported
# RR types in DNS::Resource::IN?

HELP =<<EOF
Usage: 
  mdns [options] -B        <type> [domain]         (Browse for service instances)
  mdns [options] -L <name> <type> [domain]           (Look up a service instance)
  mdns [options] -R <name> <type> [domain] <port> [<TXT>...] (Register a service)
  mdns [options] -Q <fqdn> [rrtype] [rrclass] (Generic query for any record type)

Note: -Q is not yet implemented.

For -B, -L, and -R, [domain] is optional and defaults to "local".

For -Q, [rrtype] defaults to A, other values are TXT, PTR, SRV, CNAME, ...

For -Q, [rrclass] defaults to 1 (IN).


[<TXT>...] is optional for -R, it can be a series of key=value pairs.

You can use long names --browse, --lookup, and --register instead of -B, -L,
and -R.

Options:
  -m,--mdnssd   Attempt to use 'net/dns/mdns-sd', a pure-ruby DNS-SD resolver
                library (this is the default).
  -n,--dnssd    Attempt to use 'dnssd', the interface to the native ("-n")
                DNS-SD resolver library APIs, "dns_sd.h" from Apple.
  -d,--debug    Print debug messages to stderr.

Examples:
  mdns -B _http._tcp
  mdns -L "My Music" _daap._tcp
  mdns -R me _example._tcp local 4321 key=value key2=value2

These work with the test modes of Apple's dns-sd utility:
  mdns -L Test _testupdate._tcp     (for dns-sd -A, -U, -N)
  mdns -L Test _testlargetxt._tcp   (for dns-sd -T)
  mdns -L Test _testdualtxt._tcp    (for dns-sd -M)
  mdns -L Test _testtxt._tcp        (for dns-sd -I)

EOF

opts = GetoptLong.new(
  [ "--debug",    "-d",               GetoptLong::NO_ARGUMENT ],
  [ "--help",     "-h",               GetoptLong::NO_ARGUMENT ],
  [ "--dnssd",    "-n",               GetoptLong::NO_ARGUMENT ],
  [ "--mdnssd",   "-m",               GetoptLong::NO_ARGUMENT ],

  [ "--browse",    "-B",              GetoptLong::NO_ARGUMENT ],
  [ "--lookup",    "-L",              GetoptLong::NO_ARGUMENT ],
  [ "--register",  "-R",              GetoptLong::NO_ARGUMENT ]
)

opts.each do |opt, arg|
  case opt
  when "--debug"
    require 'pp'
    require 'logger'

    @debug = true
    @log = Logger.new(STDERR)
    @log.level = Logger::DEBUG

  when "--help"
    print HELP
    exit 0

  when '--dnssd'
    require 'dnssd'
    require 'socket'

  when "--browse"
    @cmd = :browse
    @type   = ARGV.shift
    @domain = ARGV.shift || @domain

  when "--lookup"
    @cmd = :lookup
    @name   = ARGV.shift
    @type   = ARGV.shift
    @domain = ARGV.shift || @domain

    unless @name && @type
      puts 'name and type required for -L'
      exit 1
    end

  when "--register"
    @cmd = :register
    @name   = ARGV.shift
    @type   = ARGV.shift
    @port   = ARGV.shift
    if @port.to_i == 0
      @domain = @port
      @port = ARGV.shift.to_i
    else
      @port = @port.to_i
    end
    ARGV.each do |kv|
      kv.match(/([^=]+)=([^=]+)/)
      @txt[$1] = $2
    end
    ARGV.replace([])
  end
end

begin
  DNSSD.class
  puts "Using native DNSSD..."

	Thread.abort_on_exception = true # So we notice exceptions in DNSSD threads.

  module DNSSD
    def self.namesplit(n)
      n.scan(/(?:\\.|[^\.])+/)
    end
		# DNSSD > 0.6.0 uses class Reply which has these methods already
    class ResolveReply
      def domain
        DNSSD.namesplit(fullname)[-1]
      end
      def type
        DNSSD.namesplit(fullname)[1,2].join('.')
      end
      def name
        DNSSD.namesplit(fullname)[0]
      end
    end
  end
rescue NameError
  require 'net/dns/mdns-sd'
  DNSSD = Net::DNS::MDNSSD
  Net::DNS::MDNS::Responder.instance.log = @log if @log
  puts "Using Net::DNS::MDNSSD..."
end

unless @cmd
  print HELP
  exit 1
end

case @cmd
when :browse
  STDERR.puts( "DNSSD.#{@cmd}(#{@type}, #{@domain}) =>" )  if @debug

  fmt = "%-3.3s  %-8.8s   %-15.15s  %-20.20s\n"
  printf fmt, "Ttl", "Domain", "Service Type", "Instance Name"

  handle = DNSSD.browse(@type, @domain) do |reply|
    begin
      printf fmt, reply.flags.to_i, reply.domain, reply.type, reply.name
    rescue
      p $!
    end
  end

  $stdin.gets
  handle.stop


when :lookup
  STDERR.puts( "DNSSD.#{@cmd}(#{@name}, #{@type}, #{@domain}) =>" )  if @debug

  fmt = "%-3.3s  %-8.8s   %-19.19s  %-20.20s %-20.20s %s\n"
  printf fmt, "Ttl", "Domain", "Service Type", "Instance Name", "Location", "Text"

  handle = DNSSD.resolve(@name, @type, @domain) do |reply|
    begin
      location = "#{reply.target}:#{reply.port}"
      text = reply.text_record.to_a.map { |kv| "#{kv[0]}=#{kv[1].inspect}" }.join(', ')
      printf fmt, reply.flags.to_i, reply.domain, reply.type, reply.name, location, text
    rescue
      p $!
    end
  end

  $stdin.gets
  handle.stop

when :register
  STDERR.puts( "DNSSD.#{@cmd}(#{@name}, #{@type}, #{@domain}, #{@port}, #{@txt.inspect}) =>" )  if @debug

  fmt = "%-3.3s  %-8.8s   %-19.19s  %-20.20s %-20.20s %s\n"
  printf fmt, "Ttl", "Domain", "Service Type", "Instance Name", "Location", "Text"

  handle = DNSSD.register(@name, @type, @domain, @port, @txt) do |notice|
    begin
      location = "#{Socket.gethostname}:#{@port}"
      text = @txt.to_a.map { |kv| "#{kv[0]}=#{kv[1].inspect}" }.join(', ')
      printf fmt, 'N/A', notice.domain, notice.type, notice.name, location, text
    rescue
      p $!
    end
  end

  $stdin.gets
  handle.stop

end

