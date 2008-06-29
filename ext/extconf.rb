#!/usr/local/bin/ruby
#!/usr/bin/ruby
# :nodoc: all
#
#	Extension configuration script for DNS_SD C Extension.
#	$Id: extconf.rb,v 1.5 2004/10/04 18:29:53 cmills Exp $
#
#

def check_for_funcs(*funcs)
	funcs.flatten!
	funcs.each do |f|
		abort("need function #{f}") unless have_func(f)
	end
end

require "mkmf"

$CFLAGS << " -Wall"
$CFLAGS << " -DDEBUG" if $DEBUG

### Print an error message and exit with an error condition
def abort( msg )
	$stderr.puts( msg )
	exit 1
end

unless RUBY_PLATFORM.include? "darwin"
  have_library( "mdns", "DNSServiceRefSockFD" ) or
    abort( "can't find rendezvous library" )
end

#have_library( "dns-sd", "DNSServiceRefSockFD" ) or
#	abort( "Can't find rendezvous client library" )

have_header( "dns_sd.h" ) or
	abort( "can't find the rendezvous client headers" )

check_for_funcs("htons", "ntohs", "if_indextoname", "if_nametoindex")

create_makefile("rdnssd")

