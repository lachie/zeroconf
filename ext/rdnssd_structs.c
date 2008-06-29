/*
 * Copyright (c) 2004 Chad Fowler, Charles Mills, Rich Kilmer
 * Licensed under the same terms as Ruby.
 * This software has absolutely no warranty.
 */
#include "rdnssd.h"

/* for if_indextoname() */
#include <sys/types.h>
#include <sys/socket.h>
#include <net/if.h>

static VALUE cDNSSDFlags;
static VALUE cDNSSDReply;
static VALUE cDNSSDBrowseReply;
static VALUE cDNSSDResolveReply;
static VALUE cDNSSDRegisterReply;
	
static ID dnssd_iv_flags;
static ID dnssd_iv_interface;
static ID dnssd_iv_fullname;
static ID dnssd_iv_target;
static ID dnssd_iv_port;
static ID dnssd_iv_text_record;
static ID dnssd_iv_name;
static ID dnssd_iv_type;
static ID dnssd_iv_domain;
static ID dnssd_iv_service;

#define IsDNSSDFlags(obj) (rb_obj_is_kind_of(obj,cDNSSDFlags)==Qtrue)

/* dns sd flags, flag ID's, flag names */
#define DNSSD_MAX_FLAGS 9

static const DNSServiceFlags dnssd_flag[DNSSD_MAX_FLAGS] = {
	kDNSServiceFlagsMoreComing,
		
	kDNSServiceFlagsAdd,
	kDNSServiceFlagsDefault,
	
	kDNSServiceFlagsNoAutoRename,
	
	kDNSServiceFlagsShared,
	kDNSServiceFlagsUnique,
	
	kDNSServiceFlagsBrowseDomains,
	kDNSServiceFlagsRegistrationDomains,

	kDNSServiceFlagsLongLivedQuery
};

static ID dnssd_flag_iv[DNSSD_MAX_FLAGS];

static const char *dnssd_flag_name[DNSSD_MAX_FLAGS] = {
	"more_coming",
	"add",
	"default",
	"no_auto_rename",
	"shared",
	"unique",
	"browse_domains",
	"registration_domains",
	"long_lived_query"
};

static VALUE
dnssd_struct_inspect(VALUE self, volatile VALUE data)
{
	VALUE buf = rb_str_buf_new(0);
	rb_str_buf_cat2(buf, "#<");
	rb_str_buf_cat2(buf, rb_obj_classname(self));
	if (RSTRING(data)->len > 0) {
		rb_str_buf_cat2(buf, " ");
		rb_str_buf_append(buf, data);
	}
	rb_str_buf_cat2(buf, ">");
	return buf;
}

VALUE
dnssd_create_fullname(VALUE name, VALUE regtype, VALUE domain, int err_flag)
{
	char buffer[kDNSServiceMaxDomainName];
	int ret_val = DNSServiceConstructFullName(buffer,
																						NIL_P(name) ? NULL : StringValueCStr(name),
																						StringValueCStr(regtype),
																						StringValueCStr(domain)	);
	if (ret_val) {
		static const char msg[] = "could not construct full service name";
		if (err_flag) rb_raise(rb_eArgError, msg);
		/* else */
		rb_warn(msg);
		return name;
	}
	buffer[kDNSServiceMaxDomainName - 1] = '\000'; /* just in case */
	return rb_str_new2(buffer);
}

static VALUE
dnssd_get_fullname(VALUE self, int flag)
{
	return dnssd_create_fullname(	rb_ivar_get(self, dnssd_iv_name),
																rb_ivar_get(self, dnssd_iv_type),
																rb_ivar_get(self, dnssd_iv_domain), flag	);
}

/*
 * call-seq:
 *    reply.fullname => string
 *
 * The fullname of the resource the reply is associated with.
 * See DNSSD::Service.fullname() for more information.
 */

static VALUE
dnssd_reply_fullname(VALUE self)
{
	return dnssd_get_fullname(self, 1);
}

static void
dnssd_add_names(volatile VALUE self, const char *name,
								const char *regtype, const char *domain)
{
	rb_ivar_set(self, dnssd_iv_name, rb_str_new2(name));
	rb_ivar_set(self, dnssd_iv_type, rb_str_new2(regtype));
	rb_ivar_set(self, dnssd_iv_domain, rb_str_new2(domain));
}

static void
dnssd_init_flag_iv(void)
{
	/* initialize flag instance variable ids. */
	char buffer[32];
	int i;
	for (i=0; i<DNSSD_MAX_FLAGS; i++) {
		snprintf(buffer, sizeof(buffer), "@%s", dnssd_flag_name[i]);
		dnssd_flag_iv[i] = rb_intern(buffer);
	}
}

static void
dnssd_init_flags_methods(VALUE class)
{
	char buffer[128];
	int i;
	for (i=0; i<DNSSD_MAX_FLAGS; i++) {
		volatile VALUE str;
		size_t len = snprintf(buffer, sizeof(buffer),
													"def %s?; @%s end",
													dnssd_flag_name[i],
													dnssd_flag_name[i]);
		str = rb_str_new(buffer, (long)len);
		rb_mod_module_eval(1, (VALUE *)&str, class);
		/* attr_writer method for each flag */
		rb_define_attr(class, dnssd_flag_name[i], 0, 1);
	}
}

static VALUE
dnssd_flags_init(VALUE self, DNSServiceFlags flags)
{
	int i;
	for (i=0; i<DNSSD_MAX_FLAGS; i++) {
		/* check each flag using binary and, set to Qtrue of exists */
		if (flags & dnssd_flag[i]) {
			rb_ivar_set(self, dnssd_flag_iv[i], Qtrue);
		} else {
			rb_ivar_set(self, dnssd_flag_iv[i], Qfalse);
		}
	}
	return self;
}

static DNSServiceFlags 
dnssd_get_flags(VALUE self)
{
	DNSServiceFlags flags = 0;
	int i;
	for (i=0; i<DNSSD_MAX_FLAGS; i++) {
		if (RTEST(rb_ivar_get(self, dnssd_flag_iv[i]))) {
			flags |= dnssd_flag[i];
		}
	}
	return flags;
}

DNSServiceFlags 
dnssd_to_flags(VALUE obj)
{
	DNSServiceFlags flags = 0;
	if (IsDNSSDFlags(obj)) {
		flags = dnssd_get_flags(obj);
	} else {
		flags = NUM2ULONG(obj);
	}
	return flags;
}

/*
 * call-seq:
 *   DNSSD::Flags.new()         => flags
 *   DNSSD::Flags.new(integer)  => flags
 *   DNSSD::Flags.new(flags)    => dup_of_flags
 *
 * Returns a new group of flags.  In the first form,
 * none of the new flags are set.
 * In the second the flags corresponding to the bits of _integer_ are set.
 * In the third the flags set in _flags_  are set.
 *
 *   flags = Flags.new()
 *   flags.more_coming = true
 *   flags.to_i                #=> DNSSD::Flags::MoreComing
 *   f.shared = true
 *   flags.to_i                #=> Flags::MoreComing | Flags::Shared
 *   same_flags = Flags.new(Flags::MoreComing | Flags::Shared)
 *   flags == same_flags       #=> true
 *
 */

static VALUE
dnssd_flags_initialize(int argc, VALUE *argv, VALUE self)
{
	VALUE def_val = Qnil;
	DNSServiceFlags flags = 0;
	
	rb_scan_args(argc, argv, "01", &def_val);
	if (def_val != Qnil) {
		flags = dnssd_to_flags(def_val);
	}
	return dnssd_flags_init(self, flags);
}

static VALUE
dnssd_flags_new(DNSServiceFlags flags)
{
	return dnssd_flags_init(rb_obj_alloc(cDNSSDFlags), flags);
}

/*
 * call-seq:
 *    flags.to_i => an_integer
 *
 * Get the integer representation of _flags_ by bitwise or'ing
 * each of the set flags.
 */

static VALUE
dnssd_flags_to_i(VALUE self)
{
	return ULONG2NUM(dnssd_get_flags(self));
}

static VALUE
dnssd_flags_list(VALUE self)
{
	VALUE buf = rb_str_buf_new(0);
	int i;
	for (i=0; i<DNSSD_MAX_FLAGS; i++) {
		if (rb_ivar_get(self, dnssd_flag_iv[i])) {
			rb_str_buf_cat2(buf, dnssd_flag_name[i]);
			rb_str_buf_cat2(buf, ",");
		}
	}
	/* get rid of trailing comma */
	if (RSTRING(buf)->len > 0) {
		RSTRING(buf)->len--;
	}
	return buf;
}

/*
 * call-seq:
 *    flags.inspect => string
 *
 * Create a printable version of _flags_.
 *
 *    flags = DNSSD::Flags.new
 *    flags.add = true
 *    flags.default = true
 *    flags.inspect  # => "#<DNSSD::Flags add,default>"
 */

static VALUE
dnssd_flags_inspect(VALUE self)
{
	volatile VALUE data = dnssd_flags_list(self);
	return dnssd_struct_inspect(self, data);
}

/*
 * call-seq:
 *    flags == obj => true or false
 *
 * Equality--Two groups of flags are equal if the flags underlying integers
 * are equal.
 *
 *    flags = Flags.new()
 *    flags.more_coming = true
 *    flags.shared = true
 *    flags == Flags::MoreComing | Flags::Shared            #=> true
 *    flags == Flags.new(Flags::MoreComing | Flags::Shared) #=> true
 */

static VALUE
dnssd_flags_equal(VALUE self, VALUE obj)
{
	DNSServiceFlags flags = dnssd_get_flags(self);
	DNSServiceFlags obj_flags = dnssd_to_flags(obj);

	return flags == obj_flags ? Qtrue : Qfalse;
}

static VALUE
dnssd_interface_name(uint32_t interface)
{
	char buffer[IF_NAMESIZE];
	if (if_indextoname(interface, buffer)) {
		return rb_str_new2(buffer);
	} else {
		return ULONG2NUM(interface);
	}
}

static VALUE
dnssd_get_interface(VALUE self)
{
	return rb_String(rb_ivar_get(self, dnssd_iv_interface));
}

/*
 * call-seq:
 *    register_reply.inspect => string
 *
 */

static VALUE
dnssd_register_inspect(VALUE self)
{
	volatile VALUE data = dnssd_get_fullname(self, 0);
	return dnssd_struct_inspect(self, data);
}

VALUE
dnssd_register_new(VALUE service,	DNSServiceFlags flags, const char *name,
										const char *regtype, const char *domain	)
{
	volatile VALUE self = rb_obj_alloc(cDNSSDRegisterReply);
	rb_ivar_set(self, dnssd_iv_flags, dnssd_flags_new(flags));
	rb_ivar_set(self, dnssd_iv_service, service);
	dnssd_add_names(self, name, regtype, domain);
	return self;
}

/*
 * call-seq:
 *    browse_reply.inspect => string
 *
 */

static VALUE
dnssd_browse_inspect(VALUE self)
{
	volatile VALUE data = rb_str_buf_new(0);
	rb_str_buf_append(data, dnssd_get_fullname(self, 0));
	rb_str_buf_cat2(data, " interface:");
	rb_str_buf_append(data, dnssd_get_interface(self));
	return dnssd_struct_inspect(self, data);
}

VALUE
dnssd_browse_new(VALUE service,	DNSServiceFlags flags, uint32_t interface,
									const char *name, const char *regtype, const char *domain)
{
	volatile VALUE self = rb_obj_alloc(cDNSSDBrowseReply);
	rb_ivar_set(self, dnssd_iv_flags, dnssd_flags_new(flags));
	rb_ivar_set(self, dnssd_iv_interface, dnssd_interface_name(interface));
	rb_ivar_set(self, dnssd_iv_service, service);
	dnssd_add_names(self, name, regtype, domain);
	return self;
}

/*
 * call-seq:
 *    resolve_reply.inspect => string
 *
 */

static VALUE
dnssd_resolve_inspect(VALUE self)
{
	volatile VALUE data = rb_str_buf_new(0);
	rb_str_buf_append(data, rb_ivar_get(self, dnssd_iv_fullname));
	rb_str_buf_cat2(data, " interface:");
	rb_str_buf_append(data, dnssd_get_interface(self));
	rb_str_buf_cat2(data, " target:");
	rb_str_buf_append(data, rb_ivar_get(self, dnssd_iv_target));
	rb_str_buf_cat2(data, ":");
	rb_str_buf_append(data, rb_inspect(rb_ivar_get(self, dnssd_iv_port)));
	rb_str_buf_cat2(data, " ");
	rb_str_buf_append(data, rb_inspect(rb_ivar_get(self, dnssd_iv_text_record)));
	return dnssd_struct_inspect(self, data);
}

VALUE
dnssd_resolve_new(VALUE service, DNSServiceFlags flags, uint32_t interface,
									const char *fullname, const char *host_target,
									uint16_t opaqueport, uint16_t txt_len, const char *txt_rec)
{
	uint16_t port = ntohs(opaqueport);
	volatile VALUE self = rb_obj_alloc(cDNSSDResolveReply);
	rb_ivar_set(self, dnssd_iv_flags, dnssd_flags_new(flags));
	rb_ivar_set(self, dnssd_iv_interface, dnssd_interface_name(interface));
	rb_ivar_set(self, dnssd_iv_fullname, rb_str_new2(fullname));
	rb_ivar_set(self, dnssd_iv_target, rb_str_new2(host_target));
	rb_ivar_set(self, dnssd_iv_port, UINT2NUM(port));
	rb_ivar_set(self, dnssd_iv_text_record, dnssd_tr_new((long)txt_len, txt_rec));
	rb_ivar_set(self, dnssd_iv_service, service);
	return self;
}

/*
 * call-seq:
 *    DNSSD::Reply.new() => raises a RuntimeError
 *
 */
static VALUE
dnssd_reply_initialize(int argc, VALUE *argv, VALUE reply)
{
	dnssd_instantiation_error(rb_obj_classname(reply));
	return Qnil;
}

void
Init_DNSSD_Replies(void)
{
/* hack so rdoc documents the project correctly */
#ifdef mDNSSD_RDOC_HACK
	mDNSSD = rb_define_module("DNSSD");
#endif

	dnssd_iv_flags = rb_intern("@flags");
	dnssd_iv_interface = rb_intern("@interface");
	dnssd_iv_fullname = rb_intern("@fullname");
	dnssd_iv_target = rb_intern("@target");
	dnssd_iv_port = rb_intern("@port");
	dnssd_iv_text_record = rb_intern("@text_record");
	dnssd_iv_name = rb_intern("@name");
	dnssd_iv_type = rb_intern("@type");
	dnssd_iv_domain = rb_intern("@domain");
	dnssd_iv_service = rb_intern("@service");

	dnssd_init_flag_iv();

	cDNSSDFlags = rb_define_class_under(mDNSSD, "Flags", rb_cObject);
	rb_define_method(cDNSSDFlags, "initialize", dnssd_flags_initialize, -1);
	/* this creates all the attr_accessor and flag? methods */
	dnssd_init_flags_methods(cDNSSDFlags);
	rb_define_method(cDNSSDFlags, "inspect", dnssd_flags_inspect, 0);
	rb_define_method(cDNSSDFlags, "to_i", dnssd_flags_to_i, 0);
	rb_define_method(cDNSSDFlags, "==", dnssd_flags_equal, 1);

	/* prototype: rb_define_attr(class, name, read, write) */
	cDNSSDReply = rb_define_class_under(mDNSSD, "Reply", rb_cObject);
	/* DNSSD::Reply objects can only be instantiated by DNSSD.browse(), DNSSD.register(), DNSSD.resolve(). */
	rb_define_method(cDNSSDReply, "initialize", dnssd_reply_initialize, -1);
	/* Flags describing the reply.  See DNSSD::Flags for more information. */
	rb_define_attr(cDNSSDReply, "flags", 1, 0);
	/* The service associated with the reply.  See DNSSD::Service for more information. */
	rb_define_attr(cDNSSDReply, "service", 1, 0);
	rb_define_method(cDNSSDReply, "fullname", dnssd_reply_fullname, 0);

	cDNSSDBrowseReply = rb_define_class_under(mDNSSD, "BrowseReply", cDNSSDReply);
	/* The interface on which the service is advertised.
	 * The interface should be passed to DNSSD.resolve() when resolving the service. */
	rb_define_attr(cDNSSDBrowseReply, "interface", 1, 0);
	/* The service name discovered. */
	rb_define_attr(cDNSSDBrowseReply, "name", 1, 0);
	/* The service type, as passed in to DNSSD.browse(). */
	rb_define_attr(cDNSSDBrowseReply, "type", 1, 0);
	/* The domain on which the service was discovered.
	 * (If the application did not specify a domain in DNSSD.browse(),
	 * this indicates the domain on which the service was discovered.) */
	rb_define_attr(cDNSSDBrowseReply, "domain", 1, 0);
	rb_define_method(cDNSSDBrowseReply, "inspect", dnssd_browse_inspect, 0);

	cDNSSDResolveReply = rb_define_class_under(mDNSSD, "ResolveReply", cDNSSDReply);
	/* The interface on which the service was resolved. */
	rb_define_attr(cDNSSDResolveReply, "interface", 1, 0);
	/* The full service domain name, in the form "<servicename>.<protocol>.<domain>.".
	 * (Any literal dots (".") are escaped with a backslash ("\."), and literal
	 * backslashes are escaped with a second backslash ("\\"), e.g. a web server
	 * named "Dr. Pepper" would have the fullname  "Dr\.\032Pepper._http._tcp.local.".)
	 * See DNSSD::Service.fullname() for more information. */
	rb_define_attr(cDNSSDResolveReply, "fullname", 1, 0);
	/* The target hostname of the machine providing the service.
	 * This name can be passed to functions like Socket.gethostbyname()
	 * to identify the host's IP address. */
	rb_define_attr(cDNSSDResolveReply, "target", 1, 0);
	/* The port on which connections are accepted for this service. */
	rb_define_attr(cDNSSDResolveReply, "port", 1, 0);
	/* The service's primary text record, see DNSSD::TextRecord for more information. */
	rb_define_attr(cDNSSDResolveReply, "text_record", 1, 0);
	rb_define_method(cDNSSDResolveReply, "inspect", dnssd_resolve_inspect, 0);

	cDNSSDRegisterReply = rb_define_class_under(mDNSSD, "RegisterReply", cDNSSDReply);
	/* The service name registered.
	 * (If the application did not specify a name in DNSSD.register(),
	 * this indicates what name was automatically chosen.) */
	rb_define_attr(cDNSSDRegisterReply, "name", 1, 0);
	/* The type of service registered as it was passed to DNSSD.register(). */
	rb_define_attr(cDNSSDRegisterReply, "type", 1, 0);
	/* The domain on which the service was registered.
	 * (If the application did not specify a domain in DNSSD.register(),
	 * this indicates the default domain on which the service was registered.) */
	rb_define_attr(cDNSSDRegisterReply, "domain", 1, 0);
	rb_define_method(cDNSSDRegisterReply, "inspect", dnssd_register_inspect, 0);

	/* flag constants */
#if DNSSD_MAX_FLAGS != 9
	#error The code below needs to be updated.
#endif
	/* MoreComing indicates that at least one more result is queued and will be delivered following immediately after this one.
	 * Applications should not update their UI to display browse
	 * results when the MoreComing flag is set, because this would
	 * result in a great deal of ugly flickering on the screen.
	 * Applications should instead wait until until MoreComing is not set,
	 * and then update their UI.
	 * When MoreComing is not set, that doesn't mean there will be no more
	 * answers EVER, just that there are no more answers immediately
	 * available right now at this instant. If more answers become available
	 * in the future they will be delivered as usual.
	 */
	rb_define_const(cDNSSDFlags, "MoreComing", ULONG2NUM(kDNSServiceFlagsMoreComing));
	

	/* Flags for domain enumeration and DNSSD.browse() reply callbacks.
	 * DNSSD::Flags::Default applies only to enumeration and is only valid in
	 * conjuction with DNSSD::Flags::Add.  An enumeration callback with the DNSSD::Flags::Add
	 * flag NOT set indicates a DNSSD::Flags::Remove, i.e. the domain is no longer valid.
	 */
	rb_define_const(cDNSSDFlags, "Add", ULONG2NUM(kDNSServiceFlagsAdd));
	rb_define_const(cDNSSDFlags, "Default", ULONG2NUM(kDNSServiceFlagsDefault));

	/* Flag for specifying renaming behavior on name conflict when registering non-shared records.
	 * By default, name conflicts are automatically handled by renaming the service.
	 * DNSSD::Flags::NoAutoRename overrides this behavior - with this
	 * flag set, name conflicts will result in a callback.  The NoAutoRename flag
	 * is only valid if a name is explicitly specified when registering a service
	 * (ie the default name is not used.)
	 */
	rb_define_const(cDNSSDFlags, "NoAutoRename", ULONG2NUM(kDNSServiceFlagsNoAutoRename));

	/* Flag for registering individual records on a connected DNSServiceRef.
	 * DNSSD::Flags::Shared indicates that there may be multiple records
	 * with this name on the network (e.g. PTR records).  DNSSD::Flags::Unique indicates that the
	 * record's name is to be unique on the network (e.g. SRV records).
	 * (DNSSD::Flags::Shared and DNSSD::Flags::Unique are currently not used by the Ruby API.)
	 */
	rb_define_const(cDNSSDFlags, "Shared", ULONG2NUM(kDNSServiceFlagsShared));
	rb_define_const(cDNSSDFlags, "Unique", ULONG2NUM(kDNSServiceFlagsUnique));

	/* Flags for specifying domain enumeration type in DNSSD.enumerate_domains()
	 * (currently not part of the Ruby API).
	 * DNSSD::Flags::BrowseDomains enumerates domains recommended for browsing,
	 * DNSSD::Flags::RegistrationDomains enumerates domains recommended for registration.
	 */
	rb_define_const(cDNSSDFlags, "BrowseDomains", ULONG2NUM(kDNSServiceFlagsBrowseDomains));
	rb_define_const(cDNSSDFlags, "RegistrationDomains", ULONG2NUM(kDNSServiceFlagsRegistrationDomains));

	/* Flag for creating a long-lived unicast query for the DNSDS.query_record()
	 * (currently not part of the Ruby API). */
	rb_define_const(cDNSSDFlags, "LongLivedQuery", ULONG2NUM(kDNSServiceFlagsLongLivedQuery));
}

/* Document-class: DNSSD::Reply
 * 
 * DNSSD::Reply is the parent class of DNSSD::BrowseReply, DNSSD::RegisterReply, and DNSSD::ResolveReply.
 * It simply contains the behavior that is common to those classes, otherwise it is not
 * used by the DNSSD Ruby API.
 *
 */

/* Document-class: DNSSD::Flags
 * 
 * Flags used in DNSSD Ruby API.
 */

