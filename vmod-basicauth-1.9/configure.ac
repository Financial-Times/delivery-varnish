# This file is part of vmod-basicauth -*- autoconf -*-
# Copyright (C) 2013-2020 Sergey Poznyakoff
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
AC_PREREQ(2.69)
AC_INIT([vmod-basicauth], 1.9, [gray@gnu.org])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_SRCDIR(src/vmod_basicauth.vcc)
AM_CONFIG_HEADER(config.h)
AC_SUBST([AC_VMOD_BASENAME],[basicauth])
AC_CANONICAL_SYSTEM
AC_LANG(C)

AM_INIT_AUTOMAKE([1.14 gnu tar-ustar silent-rules])
AM_SILENT_RULES([yes])

AC_GNU_SOURCE
AC_PROG_CC
AC_PROG_CC_STDC
if test "x$ac_cv_prog_cc_c99" = xno; then
	AC_MSG_ERROR([could not find a C99 compatible compiler])
fi
AC_PROG_CPP

AC_PROG_INSTALL
AC_PROG_LIBTOOL
AC_PROG_MAKE_SET

# Checks for header files.
AC_HEADER_STDC
AC_CHECK_HEADERS([sys/stdlib.h crypt.h])

AM_VARNISHAPI([6.0.0],[6.4.0])

saved_LIBS=$LIBS
LIBS=-lcrypt
AC_CHECK_FUNCS([crypt_r])
LIBS=$saved_LIBS

AC_CONFIG_TESTDIR(tests)
AC_CONFIG_FILES([tests/Makefile tests/atlocal])
AM_MISSING_PROG([AUTOM4TE], [autom4te])

AC_CONFIG_FILES([
	Makefile
	src/Makefile
])
AC_OUTPUT

