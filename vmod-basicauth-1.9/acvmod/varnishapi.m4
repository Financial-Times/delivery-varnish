## Autoconf macros for writing Varnish modules
## Copyright (C) 2016-2020 Sergey Poznyakoff
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 3, or (at your option)
## any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.

## serial 3

## VAPI_CHECK_VER([MAJOR], [MINOR], [PATCH]) - Check version
##
## Arguments are literal numbers.  All of them are optional, but at least
## MAJOR must be present, otherwise the macro will produce empty expansion.
## The macro expands to shell code that compares the supplied numbers with
## the Varnish API version stored in environment variables VARNISHAPI_MAJOR,
## VARNISHAPI_MINOR, and VARNISHAPI_PATCH.  Depending on the comparison,
## the code sets variable varnishapi_version_diff to one of: "older", "newer",
## or "same".
##
m4_define([VAPI_CHECK_VER],[
  m4_if([$1],,,[if test $VARNISHAPI_MAJOR -lt $1; then
      varnishapi_version_diff=older
  elif test $VARNISHAPI_MAJOR -gt $1; then
      varnishapi_version_diff=newer
  m4_if([$2],,,[elif test $VARNISHAPI_MINOR -lt $2; then
      varnishapi_version_diff=older
  ])elif test $VARNISHAPI_MINOR -gt m4_if([$2],,0,[$2]); then
      varnishapi_version_diff=newer
  m4_if([$3],,,[elif test $VARNISHAPI_PATCH -lt $3; then
      varnishapi_version_diff=older
  ])elif test $VARNISHAPI_PATCH -gt m4_if([$3],,0,[$3]); then
      varnishapi_version_diff=newer
  else
      varnishapi_version_diff=same
  fi
])])

## AM_VARNISHAPI([MIN-VERSION],[MAX-VERSION])
## Tests if the programs and libraries needed for compiling a varnish
## module are present. If MIN-VERSION argument is supplied, checks if
## varnish API version is the same or newer than that. If it is older,
## emits error message and aborts. Otherwise, if MAX-VERSION is specified
## checks varnish API version against that. If the version is newer than
## both MAX-VERSION, a warning message to that effect will be emitted at
## the end of configure.
##
## If no arguments are given, and the package version string ends in -N.N.N,
## (where N stands for a decimal digit), the macro behaves as if it were
## called as AM_VARNISHAPI([N.N.N]).
##
## Sets the following configuration variables:
##
##   VMODDIR         the path of the varnish module directory.
##   VARNISH_MAJOR, VARNISH_MINOR, and VARNISH_PATCH
##                   the corresponding numbers of the varnish API version.
##   VARNISHD        full pathname of the varnishd binary.
##   VARNISHTEST     full pathname of the varnishtest binary.
##   VARNISHAPI_PKGDATADIR
##                   varnish API package data directory.
##   VARNISHAPI_VMODTOOL
##                   full pathname of the vmodtool.py script.
##   PYTHON          full pathname of the python 3 binary.
##   RST2MAN         full pathname of the rst2man or rst2man.py script.
##
AC_DEFUN([AM_VARNISHAPI],
[ # Check for pkg-config
  PKG_PROG_PKG_CONFIG

  # Check for python
  AM_PATH_PYTHON([3.5])

  # Check for rst2man.py or rst2man
  AC_PATH_PROGS(RST2MAN, [rst2man.py rst2man],
    [\$(abs_top_srcdir)/build-aux/missing rst2man.py])
  AC_SUBST([RST2MAN])
  
  # pkg-config
  PKG_PROG_PKG_CONFIG
  PKG_CHECK_MODULES([VARNISHAPI], [varnishapi])

  varnishapi_version() {
    VARNISHAPI_MAJOR=$[]1
    VARNISHAPI_MINOR=$[]2
    VARNISHAPI_PATCH=$[]3
  }

  v=$($PKG_CONFIG --modversion varnishapi)

  if test -n "$v"; then
    save_IFS=$IFS
    IFS='.'
    varnishapi_version $v
    IFS=$save_IFS

    m4_pushdef([ver],[m4_bpatsubst(AC_PACKAGE_VERSION,[.*-\([0-9]\.[0-9]\.[0-9]\)$],[\1])])

    VAPI_CHECK_VER(m4_unquote(m4_split(m4_if([ver],AC_PACKAGE_VERSION,[$1],[$1],,[ver],[$1]),\.)))
    if test $varnishapi_version_diff = older; then
      AC_MSG_ERROR([varnishapi version too old: $VARNISHAPI_MAJOR.$VARNISHAPI_MINOR.$VARNISHAPI_PATCH; required at least $1])
    fi

    m4_if([$2],,[m4_if(ver,AC_PACKAGE_VERSION,[# Suppress the warning message
    varnishapi_version_diff=same])],dnl
    [if test "$varnishapi_version_diff" = newer; then
       VAPI_CHECK_VER(m4_unquote(m4_split([$2],\.)))
     fi])
    m4_popdef([ver])
  else
    AC_MSG_ERROR([unknown varnishapi version])
  fi

  if test "$VARNISHAPI_MAJOR" -eq 6; then
      save_cflags=$CFLAGS
      CFLAGS=$VARNISHAPI_CFLAGS
      AC_CHECK_DECLS([WS_ReserveAll,WS_ReserveSize],[],[],
		 [#include <cache/cache.h>
#include <vcl.h>
])
      CFLAGS=$save_cflags
      AH_BOTTOM([/*
 * The two functions below appeared in 6.0 and were removed in
 * versions 6.1 and 6.2 only to resurge in 6.3, with the additional
 * notice that they are going to replace the WS_Reserve function,
 * which will be removed after 2020-09-15.
 * (see http://varnish-cache.org/docs/trunk/whats-new/upgrading-6.3.html)
 * These macros work around this vacillation.
 */
#if !HAVE_DECL_WS_RESERVEALL
# define WS_ReserveAll(ws) WS_Reserve(ws,0)
#endif
#if !HAVE_DECL_WS_RESERVESIZE
# define WS_ReserveSize(ws,sz) WS_Reserve(ws,sz)
#endif
])  
  fi
  
  # vmod installation dir
  AC_ARG_VAR([VMODDIR],  [vmod installation directory])
  AC_ARG_WITH([vmoddir],
    AC_HELP_STRING([--with-vmoddir=DIR],
                   [install modules to DIR]),
    [case "$withval" in
     /*)   VMODDIR=$withval;;
     no)   unset VMODDIR;;
     *)    AC_MSG_ERROR([argument to --with-vmoddir must be absolute pathname])
     esac],[VMODDIR=$($PKG_CONFIG --variable=vmoddir varnishapi)
     if test -z "$VMODDIR"; then
       AC_MSG_FAILURE([cannot determine vmod installation directory])
     fi])

  if test -z "$VMODDIR"; then
    VMODDIR='$(libdir)/varnish/mods'
  fi

  AC_ARG_VAR([VARNISH_BINDIR],[Varnish bin directory])
  VARNISH_BINDIR=$($PKG_CONFIG --variable=bindir varnishapi)

  AC_ARG_VAR([VARNISH_SBINDIR],[Varnish sbin directory])
  VARNISH_SBINDIR=$($PKG_CONFIG --variable=sbindir varnishapi)
  
  AC_ARG_VAR([VARNISHD],[full pathname of the varnishd binary])
  AC_PATH_PROG([VARNISHD],
               [varnishd],[\$(abs_top_srcdir)/build-aux/missing varnishd],
               [$VARNISH_SBINDIR:$PATH])
  AC_ARG_VAR([VARNISHTEST],[full pathname of the varnishtest binary])
  AC_PATH_PROG([VARNISHTEST],
               [varnishtest],[\$(abs_top_srcdir)/build-aux/missing varnishtest],
               [$VARNISH_BINDIR:$PATH])

  AC_ARG_VAR([VARNISHAPI_PKGDATADIR],[full pathname of the varnish lib directory])
  VARNISHAPI_PKGDATADIR=$($PKG_CONFIG --variable=pkgdatadir varnishapi)
  AC_ARG_VAR([VARNISHAPI_VMODTOOL],[full pathname of the vmodtool.py script])
  VARNISHAPI_VMODTOOL='$(VARNISHAPI_PKGDATADIR)/vmodtool.py'
  
  AC_CONFIG_COMMANDS([status],[
delim="---------------------------------------------------------------------------"
echo ""
echo $delim
echo "Building for Varnish version $version"
if test "$varnishapi_version_diff" = newer; then
  fmt <<EOT
WARNING: This version is newer than the latest version for which
$PACKAGE_STRING was tested ($2).  If it doesn't compile, please report it to
<$PACKAGE_BUGREPORT>.
EOT
fi
echo $delim
echo ""
],
[version="$VARNISHAPI_MAJOR.$VARNISHAPI_MINOR"
if test -n "$VARNISHAPI_PATCH"; then
  version="\$version.$VARNISHAPI_PATCH"
fi
varnishapi_version_diff=$varnishapi_version_diff
PACKAGE_STRING="$PACKAGE_STRING"
PACKAGE_BUGREPORT=$PACKAGE_BUGREPORT
])])

## varnishapi.m4 ends
