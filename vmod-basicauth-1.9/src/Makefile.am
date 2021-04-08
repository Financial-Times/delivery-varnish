# This file is part of vmod-basicauth 
# Copyright (C) 2013-2014 Sergey Poznyakoff
#
# Vmod-basicauth is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# Vmod-basicauth is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with vmod-basicauth.  If not, see <http://www.gnu.org/licenses/>.

AM_CPPFLAGS=\
 $(VARNISHAPI_CFLAGS)

dist_man_MANS = vmod-basicauth.3 vmod_basicauth.3

vmoddir = $(VMODDIR)
vmod_LTLIBRARIES = libvmod_basicauth.la

libvmod_basicauth_la_LDFLAGS = -module -export-dynamic -avoid-version
libvmod_basicauth_la_LIBADD = -lcrypt

libvmod_basicauth_la_SOURCES = \
	basicauth.h\
	md5.c\
	sha1.c\
	sha1.h\
	vmod_basicauth.c

nodist_libvmod_basicauth_la_SOURCES = vcc_if.c vcc_if.h

vmod_basicauth.lo: vcc_if.h

CLEANFILES = vcc_if.c vcc_if.h *.rst

vmodtoolargs = --strict
vccfile = $(top_srcdir)/src/vmod_basicauth.vcc

vcc_if.c vcc_if.h: $(vmodtool) $(vccfile)
	$(AM_V_GEN)$(PYTHON) $(VARNISHAPI_VMODTOOL) $(vmodtoolargs) $(vccfile)

EXTRA_DIST = \
	vmod_basicauth.vcc


