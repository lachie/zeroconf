#!/usr/local/bin/ruby18 -w
# Author: Sam Roberts <sroberts@uniserve.com>
# Licence: this file is placed in the public domain

$:.unshift(File.dirname($0))

require 'getoptlong'
require 'net/dns/resolv-mdns'
require 'pp'

rrmap = {
  'a'   => Resolv::DNS::Resource::IN::A,
  'any' => Resolv::DNS::Resource::IN::ANY,
  'ptr' => Resolv::DNS::Resource::IN::PTR,
  'srv' => Resolv::DNS::Resource::IN::SRV,
  nil   => Resolv::DNS::Resource::IN::ANY
}

rtypes = rrmap.keys.join ', '

HELP =<<EOF
Usage: mdns [options] name [service-type]

Options
  -h,--help      Print this helpful message.
  -t,--type      Query for this specific resource record type.
  -r,--recur     Recursive query.
  -a,--addr      Do an address lookup on name using mDNS-aware Resolv#getaddress.
  -d,--debug     Print debug information.

Supported record types are:
  #{rrmap.keys.compact.join "\n  "}

Default is 'any'.

Examples:
EOF

opt_debug = nil
opt_recur = nil
opt_addr  = nil
opt_type  = Resolv::DNS::Resource::IN::ANY

opts = GetoptLong.new(
  [ "--help",    "-h",              GetoptLong::NO_ARGUMENT ],
  [ "--type",    "-t",              GetoptLong::REQUIRED_ARGUMENT],
  [ "--recur",   "-r",              GetoptLong::NO_ARGUMENT ],
  [ "--addr",    "-a",              GetoptLong::NO_ARGUMENT ],
  [ "--debug",   "-d",              GetoptLong::NO_ARGUMENT ]
)

opts.each do |opt, arg|
  case opt
    when "--help"  then puts HELP; exit 0
    when "--debug" then opt_debug = true
    when "--recur" then opt_recur = true
    when "--addr"  then opt_addr = true
    when "--type"  then opt_type = rrmap[arg]
  end
end

r = Resolv::MDNS.new

r.lazy_initialize

Name = Resolv::DNS::Name

ARGV.each do |n|
  argv0 = Name.create(n)

  unless argv0.absolute?
    if argv0.to_s[0] == ?_
      if argv0.length == 1
        argv0 = Name.create(argv0.to_s + '._tcp')
      end

      if argv0.length == 2
        argv0 = Name.create(argv0.to_s + '.local')
      end
    else
      if argv0.length == 1
        argv0 = Name.create(argv0.to_s + '.local')
      end
    end
  end

  puts "#{n} -> #{argv0}"

  if( opt_addr )
    pp Resolv.getaddress(argv0.to_s)
  else

    # r.each_resource(argv0, opt_type) do |rr| # BUG - this never times out...
    r.getresources(argv0, opt_type).each do |rr|
      pp rr

      if opt_recur
        case rr
        when Resolv::DNS::Resource::IN::PTR
          n = rr.name

          r.each_resource(n, Resolv::DNS::Resource::IN::ANY) do |rr1|
            pp rr1
          end
          # TODO - A query for SRV.target
        end
      end
    end
  end
end

