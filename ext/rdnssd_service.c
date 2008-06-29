/*
 * Ruby Rendezvous Binding
 * $Id: rdnssd_service.c,v 1.12 2004/10/07 15:19:14 cmills Exp $
 *
 * Copyright (c) 2004 Chad Fowler, Charles Mills, Rich Kilmer
 * Licenced under the same terms as Ruby.
 * This software has absolutely no warranty.
 */

#include "rdnssd.h"
#include <intern.h>

/* for if_nametoindex() */
#include <sys/types.h>
#include <sys/socket.h>
#include <net/if.h>

#ifndef DNSSD_API
	/* define as nothing if not defined in "dns_sd.h" header  */
	#define DNSSD_API 
#endif

static VALUE cDNSSDService;
static ID dnssd_id_call;
static ID dnssd_id_to_str;
static ID dnssd_iv_block;
static ID dnssd_iv_thread;
static ID dnssd_iv_service;

#define IsDNSSDService(obj) (rb_obj_is_kind_of(obj,cDNSSDService)==Qtrue)
#define GetDNSSDService(obj, var) Data_Get_Struct(obj, DNSServiceRef, var)

static VALUE dnssd_process(VALUE service);

static void
dnssd_check_block(VALUE block)
{
	if (block == Qnil) {
		rb_raise(rb_eArgError, "block required");
	}
}

static const char *
dnssd_get_domain(VALUE service_domain)
{
	const char *domain = StringValueCStr(service_domain);
	/* max len including the null terminator and trailing '.' */
	if (strlen(domain) >= kDNSServiceMaxDomainName - 1)
		rb_raise(rb_eArgError, "domain name string too large");
	return domain;
}

static uint32_t
dnssd_get_interface_index(VALUE interface)
{
	/* if the interface is a string then convert it to the interface index */
	if (rb_respond_to(interface, dnssd_id_to_str)) {
		return if_nametoindex(StringValueCStr(interface));
	} else {
		return (uint32_t)NUM2ULONG(interface);
	}
}

/*
 * call-seq:
 *    DNSSD::Serivce.fullname(name, type, domain) => string
 *
 * Concatenate a three-part domain name (as seen in DNSSD::Reply#fullname())
 * into a properly-escaped full domain name.
 *
 * Any dots or slashes in the _name_ must NOT be escaped.
 * May be <code>nil</code> (to construct a PTR record name, e.g. "_ftp._tcp.apple.com").
 *
 * The _type_ is the service type followed by the protocol, separated by a dot (e.g. "_ftp._tcp").
 *
 * The _domain_ is the domain name, e.g. "apple.com".  Any literal dots or backslashes
 * must be escaped.
 *
 * Raises a <code>ArgumentError</code> if the full service name cannot be constructed from
 * the arguments.
 */

static VALUE
dnssd_service_fullname(VALUE klass, VALUE name, VALUE type, VALUE domain)
{
	return dnssd_create_fullname(name, type, domain, 1);
}

/*
 * call-seq:
 *    DNSSD::Serivce.new() => raises a RuntimeError
 *
 * Services can only be instantiated using DNSSD.browse(), DNSSD.register(), and DNSSD.resolve().
 */

static VALUE
dnssd_service_new(int argc, VALUE *argv, VALUE klass)
{
	dnssd_instantiation_error(rb_class2name(klass));
	return Qnil;
}

static void
dnssd_service_stop_client(VALUE service)
{
	DNSServiceRef *client = (DNSServiceRef*)RDATA(service)->data;
	/* set to null right away for a bit more thread safety */
	RDATA(service)->data = NULL;
  DNSServiceRefDeallocate(*client);
	free(client); /* free the pointer */
}

static void
dnssd_service_free(void *ptr)
{
	DNSServiceRef *client = (DNSServiceRef*)ptr;
	if (client) {
		/* client will be non-null only if client has not been deallocated
		 * see dnssd_service_stop_client() above. */
		DNSServiceRefDeallocate(*client);
		free(client); /* free the pointer, see dnssd_service_alloc() below */
	}
}

static VALUE
dnssd_service_alloc(VALUE block)
{
  DNSServiceRef *client = ALLOC(DNSServiceRef);
	VALUE service = Data_Wrap_Struct(cDNSSDService, 0, dnssd_service_free, client);
  rb_ivar_set(service, dnssd_iv_block, block);
  rb_ivar_set(service, dnssd_iv_thread, Qnil);
	return service;
}

static void
dnssd_service_start(VALUE service)
{
  VALUE thread = rb_thread_create(dnssd_process, (void *)service);
  rb_ivar_set(service, dnssd_iv_thread, thread);
	/* !! IMPORTANT: prevents premature garbage collection of the service,
	 * this way the thread holds a reference to the service and
	 * the service gets marked as long as the thread is running.
	 * Running threads are always marked by Ruby. !! */
	rb_ivar_set(thread, dnssd_iv_service, service);
}

/*
 * call-seq:
 *    service.stopped? => true or false
 *
 * Returns <code>true</code> if _service_ has been stopped, <code>false</code> otherwise.
 */

static VALUE
dnssd_service_is_stopped(VALUE service)
{
  return NIL_P(rb_ivar_get(service, dnssd_iv_thread)) ? Qtrue : Qfalse;
}

/*
 * call-seq:
 *    service.stop => service
 *
 * Stops the DNSSD::Service _service_; closing the underlying socket and killing
 * the underlying thread.
 */

static VALUE
dnssd_service_stop(VALUE service)
{
	VALUE thread = rb_ivar_get(service, dnssd_iv_thread);
	if (NIL_P(thread)) rb_raise(rb_eRuntimeError, "service is already stopped");

	/* mark service as stopped, then kill thread -
	 * just in case stop is called in thread! :( */
	rb_ivar_set(service, dnssd_iv_thread, Qnil);
	rb_thread_kill(thread);

	/* once thread is killed we don't need to reference the block any more */
  rb_ivar_set(service, dnssd_iv_block, Qnil);
 
	/* do this last! - thread must be killed */
	dnssd_service_stop_client(service);
  return service;
}

/*
 * call-seq:
 *    service.inspect => string
 *
 */

static VALUE
dnssd_service_inspect(VALUE self)
{
	VALUE buf = rb_str_buf_new(0);
	rb_str_buf_cat2(buf, "<#");
	rb_str_buf_cat2(buf, rb_obj_classname(self));
	if (dnssd_service_is_stopped(self)) {
		rb_str_buf_cat2(buf, " (stopped)");
	}
	rb_str_buf_cat2(buf, ">");
	return buf;
}

static VALUE
dnssd_service_get_block(VALUE service)
{
	return rb_ivar_get(service, dnssd_iv_block);
}

static VALUE
dnssd_process(VALUE service)
{
  int dns_sd_fd, nfds, result;
  fd_set readfds;

  DNSServiceRef *client;
  GetDNSSDService(service, client);

  dns_sd_fd = DNSServiceRefSockFD (*client);
  nfds = dns_sd_fd + 1;
  while (1) {
    FD_ZERO (&readfds);
    FD_SET (dns_sd_fd, &readfds);
    result = rb_thread_select (nfds, &readfds, (fd_set *) NULL, (fd_set *) NULL, (struct timeval *) NULL);
    if (result > 0) {
      if (FD_ISSET (dns_sd_fd, &readfds)) {
        DNSServiceProcessResult(*client);
      }
    } else {
      break;
    }
  }
  return Qnil;
}

static void DNSSD_API
dnssd_browse_reply (DNSServiceRef client, DNSServiceFlags flags,
										uint32_t interface_index, DNSServiceErrorType errorCode,
							      const char *replyName, const char *replyType,
										const char *replyDomain, void *context)
{
  VALUE service, block, browse_reply;
	/* other parameters are undefined if errorCode != 0 */
	dnssd_check_error_code(errorCode);
	
	service = (VALUE)context;
	block = dnssd_service_get_block(service);
	browse_reply = dnssd_browse_new(service, flags, interface_index,
																	replyName, replyType, replyDomain);

	/* client is wrapped by service */
  rb_funcall2(block, dnssd_id_call, 1, &browse_reply);
}

/*
 * call-seq:
 *    DNSSD.browse(service_type, domain=nil, flags=0, interface=DNSSD::InterfaceAny) do |browse_reply|
 *      block
 *    end => service_handle
 *
 * Browse for DNSSD services.
 * For each service found DNSSD::BrowseReply object is passed to block.
 * The returned _service_handle_ can be used to control when to
 * stop browsing for services (see DNSSD::Service#stop).
 *
 */
 
static VALUE
dnssd_browse (int argc, VALUE * argv, VALUE self)
{
  VALUE service_type, domain, tmp_flags, interface, block;
	
	const char *type_str;
	const char *domain_str = NULL;
	DNSServiceFlags flags = 0;
	uint32_t interface_index = 0;

  DNSServiceErrorType e;
	DNSServiceRef *client;
  VALUE service;

  rb_scan_args (argc, argv, "13&", &service_type, &domain,
								&tmp_flags, &interface, &block);

	/* required */
	dnssd_check_block(block);
	type_str = StringValueCStr(service_type);

	/* optional parameters */
  if (domain != Qnil)
		domain_str = dnssd_get_domain(domain);
	if (tmp_flags != Qnil)
		flags = dnssd_to_flags(tmp_flags);
	if (interface != Qnil)
		interface_index = dnssd_get_interface_index(interface);
	
	/* allocate this last since all other parameters are on the stack (thanks to & unary operator) */
	service = dnssd_service_alloc(block);
	GetDNSSDService(service, client);
	
  e = DNSServiceBrowse (client, flags, interface_index,
												type_str, domain_str,
												dnssd_browse_reply, (void *)service);
  dnssd_check_error_code(e);
	dnssd_service_start(service);
  return service;
}

static void DNSSD_API
dnssd_register_reply (DNSServiceRef client, DNSServiceFlags flags,
											DNSServiceErrorType errorCode,
											const char *name, const char *regtype,
											const char *domain, void *context)
{
	VALUE service, block, register_reply;
	/* other parameters are undefined if errorCode != 0 */
	dnssd_check_error_code(errorCode);

  service = (VALUE)context;
  block = dnssd_service_get_block(service);
	register_reply = dnssd_register_new(service, flags, name, regtype, domain);

  rb_funcall2(block, dnssd_id_call, 1, &register_reply);
}

/*
 * call-seq:
 *    DNSSD.register(service_name, service_type, service_domain, service_port, text_record=nil, flags=0, interface=DNSSD::InterfaceAny) do |register_reply|
 *      block
 *    end => service_handle
 *
 * Register a service.
 * If a block is provided a DNSSD::RegisterReply object will passed to the block
 * when the registration completes or asynchronously fails.
 * If no block is passed the client will not be notified of the default values picked
 * on its behalf or of any error that occur.
 * The returned _service_handle_ can be used to control when to
 * stop the service (see DNSSD::Service#stop).
 */

static VALUE
dnssd_register (int argc, VALUE * argv, VALUE self)
{
  VALUE service_name, service_type, service_domain, service_port,
				text_record, tmp_flags, interface, block;

	const char *name_str, *type_str, *domain_str = NULL;
	uint16_t opaqueport;
	uint16_t txt_len = 0;
	char *txt_rec = NULL;
	DNSServiceFlags flags = 0;
	uint32_t interface_index = 0;

  DNSServiceErrorType e;
  DNSServiceRef *client;
  VALUE service;

  rb_scan_args (argc, argv, "43&",
								&service_name, &service_type,
								&service_domain, &service_port,
								&text_record, &tmp_flags,
								&interface, &block);

	/* required parameters */
	dnssd_check_block(block); /* in the future this may not be required */
	name_str = StringValueCStr(service_name);
	type_str = StringValueCStr(service_type);

	if (service_domain != Qnil)
		domain_str = dnssd_get_domain(service_domain);
	/* convert from host to net byte order */
	opaqueport = htons((uint16_t)NUM2UINT(service_port));

	/* optional parameters */
	if (text_record != Qnil) {
		text_record = dnssd_tr_to_encoded_str(text_record);
		txt_rec = RSTRING(text_record)->ptr;
		txt_len = RSTRING(text_record)->len;
	}
	if (tmp_flags != Qnil)
		flags = dnssd_to_flags(tmp_flags);
  if(interface != Qnil)
		interface_index = dnssd_get_interface_index(interface);

	/* allocate this last since all other parameters are on the stack (thanks to & unary operator) */
	service = dnssd_service_alloc(block);
  GetDNSSDService(service, client);

  e = DNSServiceRegister( client, flags, interface_index,
													name_str, type_str, domain_str,
													NULL, opaqueport, txt_len, txt_rec,
													/*block == Qnil ? NULL : dnssd_register_reply,*/
													dnssd_register_reply, (void*)service );
  dnssd_check_error_code(e);
  dnssd_service_start(service);
  return service;
}

/*
set text record using AddRecord
static VALUE
dnssd_service_record(VALUE self, VALUE text_record)
{
	VALUE text_record, flags, time_to_live;
	
	
	text_record = dnssd_tr_to_encoded_str(text_record);
	
}
*/

static void DNSSD_API
dnssd_resolve_reply (DNSServiceRef client, DNSServiceFlags flags,
										 uint32_t interface_index, DNSServiceErrorType errorCode,
										 const char *fullname, const char *host_target,
										 uint16_t opaqueport, uint16_t txt_len,
										 const char *txt_rec, void *context)
{
	/* other parameters are undefined if errorCode != 0 */
	dnssd_check_error_code(errorCode);
	VALUE service, block, resolve_reply;

	service = (VALUE)context;
  block = dnssd_service_get_block(service);
	resolve_reply = dnssd_resolve_new(service, flags, interface_index,
																		fullname, host_target, opaqueport,
																		txt_len, txt_rec);
  
	rb_funcall2(block, dnssd_id_call, 1, &resolve_reply);
}

/*
 * call-seq:
 *    DNSSD.resolve(service_name, service_type, service_domain, flags=0, interface=DNSSD::InterfaceAny) do |resolve_reply|
 *      block
 *    end => service_handle
 *
 * Resolve a service discovered via DNSSD.browse().
 * The service is resolved to a target host name, port number, and text record - all contained
 * in the DNSSD::ResolveReply object passed to the required block.  
 * The returned _service_handle_ can be used to control when to
 * stop resolving the service (see DNSSD::Service#stop).
 */

static VALUE
dnssd_resolve(int argc, VALUE * argv, VALUE self)
{
  VALUE service_name, service_type, service_domain,
				tmp_flags, interface, block;

	const char *name_str, *type_str, *domain_str;
	DNSServiceFlags flags = 0;
	uint32_t interface_index = 0;

  DNSServiceErrorType err;
  DNSServiceRef *client;
  VALUE service;

  rb_scan_args (argc, argv, "32&",
								&service_name, &service_type, &service_domain,
								&tmp_flags, &interface, &block);

	/* required parameters */
	dnssd_check_block(block);
	name_str = StringValueCStr(service_name),
	type_str = StringValueCStr(service_type),
	domain_str = dnssd_get_domain(service_domain);

	/* optional parameters */
	if (tmp_flags != Qnil)
		flags = dnssd_to_flags(tmp_flags);
	if (interface != Qnil) {
		interface_index = dnssd_get_interface_index(interface);
	}

	/* allocate this last since all other parameters are on the stack (thanks to unary & operator) */
	service = dnssd_service_alloc(block);
  GetDNSSDService(service, client);

  err = DNSServiceResolve (client, flags, interface_index, name_str, type_str,
													 domain_str, dnssd_resolve_reply, (void *) service);
  dnssd_check_error_code(err);
	dnssd_service_start(service);
  return service;
}

void
Init_DNSSD_Service(void)
{
/* hack so rdoc documents the project correctly */
#ifdef mDNSSD_RDOC_HACK
	mDNSSD = rb_define_module("DNSSD");
#endif
	dnssd_id_call = rb_intern("call");
	dnssd_id_to_str = rb_intern("to_str");
	dnssd_iv_block = rb_intern("@block");
	dnssd_iv_thread = rb_intern("@thread");
	dnssd_iv_service = rb_intern("@service");

	cDNSSDService = rb_define_class_under(mDNSSD, "Service", rb_cObject);

	rb_define_singleton_method(cDNSSDService, "new", dnssd_service_new, -1);
	rb_define_singleton_method(cDNSSDService, "fullname", dnssd_service_fullname, 3);
	
	rb_define_method(cDNSSDService, "stop", dnssd_service_stop, 0);
	rb_define_method(cDNSSDService, "stopped?", dnssd_service_is_stopped, 0);
	rb_define_method(cDNSSDService, "inspect", dnssd_service_inspect, 0);
	
  rb_define_module_function(mDNSSD, "browse", dnssd_browse, -1);
  rb_define_module_function(mDNSSD, "resolve", dnssd_resolve, -1);
  rb_define_module_function(mDNSSD, "register", dnssd_register, -1);
}

