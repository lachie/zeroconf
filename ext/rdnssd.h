/*
 * Copyright (c) 2004 Chad Fowler, Charles Mills, Rich Kilmer
 * Licenced under the same terms as Ruby.
 * This software has absolutely no warrenty.
 */
#ifndef RDNSSD_INCLUDED
#define RDNSSD_INCLUDED

#include <ruby.h>
#include <dns_sd.h>

extern VALUE mDNSSD;

void	dnssd_check_error_code(DNSServiceErrorType e);
void	dnssd_instantiation_error(const char *what);

VALUE	dnssd_create_fullname(VALUE name, VALUE regtype, VALUE domain, int err_flag);

/* decodes a buffer, creating a new text record */
VALUE	dnssd_tr_new(long len, const char *buf);

VALUE	dnssd_tr_to_encoded_str(VALUE v);

/* Get DNSServiceFlags from self */
DNSServiceFlags dnssd_to_flags(VALUE obj);

VALUE	dnssd_register_new(VALUE service,	DNSServiceFlags flags, const char *name,
													const char *regtype, const char *domain	);

VALUE	dnssd_browse_new(VALUE service,	DNSServiceFlags flags, uint32_t interface,
												const char *name, const char *regtype, const char *domain);

VALUE	dnssd_resolve_new(VALUE service, DNSServiceFlags flags, uint32_t interface,
												const char *fullname, const char *host_target,
												uint16_t opaqueport, uint16_t txt_len, const char *txt_rec);

#endif /* RDNSSD_INCLUDED */

