m4_version_prereq([2.52g])

m4_define([AT_SKIP_TEST],[exit 77])

dnl AT_VARNISHTEST(VCL, CLT[, SRV])
m4_define([AT_VARNISHTEST],[
AT_CHECK([
cat > test.vtc <<EOT
varnishtest "$at_desc"
server s1 {
m4_if($3,,[dnl
        rxreq
        txresp],[$3])
} -start

varnish v1 -vcl+backend {
	import std;
        import AT_VMOD_BASENAME from "[$abs_top_builddir/src/.libs/libvmod_]AT_VMOD_BASENAME[.so]";
$1
} -start

client c1 {
$2
} -run
EOT
$VARNISHTEST \
 -Dvarnishd="$VARNISHD"\
 -Dvmod_topsrc=$abs_top_srcdir\
 -Dvmod_topbuild=$abs_top_builddir test.vtc | sed 's/^#.*TEST test.vtc passed.*/OK/'
],
[0],
[OK
])])

# End of testsuite.inc
