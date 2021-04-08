/* This file is part of vmod-basicauth
   Copyright (C) 2013-2014 Sergey Poznyakoff

   Vmod-basicauth is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   Vmod-basicauth is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with vmod-basicauth.  If not, see <http://www.gnu.org/licenses/>.
*/
#define _GNU_SOURCE
#include <config.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <syslog.h>
#include <unistd.h>
#include <stdbool.h>
#ifdef HAVE_CRYPT_H
# include <crypt.h>
#endif

#include "vdef.h"
#include "vrt.h"
#include "vcl.h"
#include "vcc_if.h"
#include "pthread.h"

#define MOD_CTX const struct vrt_ctx *

#include "basicauth.h"
#include "sha1.h"

static int b64val[128] = {
    	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
	-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63,
        52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1,
	-1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
        15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1,
	-1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
        41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1
};

static int
base64_decode(const unsigned char *input, size_t input_len,
              unsigned char *output, size_t output_len)
{
	unsigned char *out = output;
#define AC(c) do { if (output_len-- == 0) return -1; *out++ = (c); } while (0)
	
    	if (!out)
        	return -1;

    	do {
        	if (input[0] > 127 || b64val[input[0]] == -1 || 
                    input[1] > 127 || b64val[input[1]] == -1 || 
                    input[2] > 127 || 
                    ((input[2] != '=') && (b64val[input[2]] == -1)) || 
                    input[3] > 127 || 
                    ((input[3] != '=') && (b64val[input[3]] == -1))) {
            		errno = EINVAL;
            		return -1;
        	}
        	AC((b64val[input[0]] << 2) | (b64val[input[1]] >> 4));
        	if (input[2] != '=') {
            		AC(((b64val[input[1]] << 4) & 0xf0) | 
                           (b64val[input[2]] >> 2));
            		if (input[3] != '=')
                		AC(((b64val[input[2]] << 6) & 0xc0) | 
                                    b64val[input[3]]);
        	}
        	input += 4;
        	input_len -= 4;
    	} while (input_len > 0);
    	return out - output;
}

#ifdef HAVE_CRYPT_R
struct priv_data {
       struct crypt_data cdat;
};

static struct priv_data *
get_priv_data(struct vmod_priv *priv)
{
	if (!priv->priv) {
		struct priv_data *p = malloc(sizeof(*p));
		p->cdat.initialized = 0;
		priv->priv = p;
		priv->free = free;
	}
	return priv->priv;
}
#else
static pthread_mutex_t pass_mutex = PTHREAD_MUTEX_INITIALIZER;
#endif

/* Matchers */

static int
crypt_match(const char *pass, const char *hash, struct vmod_priv *priv)
{
	int res = 1;
	char *cp;
	
#ifdef HAVE_CRYPT_R
	cp = crypt_r(pass, hash, &get_priv_data(priv)->cdat);
	if (cp)
		res = strcmp(cp, hash);
#else
	pthread_mutex_lock(&pass_mutex);
	cp = crypt(pass, hash);
	if (cp)
		res = strcmp(cp, hash);
	pthread_mutex_unlock(&pass_mutex);
#endif
	return res;
}

static int
plain_match(const char *pass, const char *hash, struct vmod_priv *priv)
{
	return strcmp(pass, hash);
}

static int
apr_match(const char *pass, const char *hash, struct vmod_priv *priv)
{
	char buf[120];
	char *cp = apr_md5_encode(pass, hash, buf, sizeof(buf));
	return cp ? strcmp(cp, hash) : 1;
}

#define SHA1_DIGEST_SIZE 20

static int
sha1_match(const char *pass, const char *hash, struct vmod_priv *priv)
{
	char hashbuf[SHA1_DIGEST_SIZE], resbuf[SHA1_DIGEST_SIZE];
	int n;
	
	hash += 5; /* Skip past {SHA} */
	n = base64_decode((const unsigned char *)hash, strlen(hash),
			  (unsigned char *)hashbuf, sizeof(hashbuf));
	if (n < 0) {
		syslog(LOG_AUTHPRIV|LOG_ERR, "cannot decode %s", hash);
		return 1;
	}
	if (n != SHA1_DIGEST_SIZE) {
		syslog(LOG_AUTHPRIV|LOG_ERR, "bad hash length: %s %d", hash, n);
		return 1;
	}
	sha1_buffer(pass, strlen(pass), resbuf);

	return memcmp(resbuf, hashbuf, SHA1_DIGEST_SIZE);
}

/* Matcher table */
struct matcher {
	char *cm_pfx;
	size_t cm_len;
	int (*cm_match)(const char *, const char *, struct vmod_priv *priv);
};

static struct matcher match_tab[] = {
#define S(s) #s, sizeof(#s)-1
	{ S($apr1$), apr_match },
	{ S({SHA}), sha1_match },
	{ "", 0, crypt_match },
	{ "", 0, plain_match },
	{ NULL }
};

static int
match(const char *pass, const char *hash, struct vmod_priv *priv)
{
	struct matcher *p;
	size_t plen = strlen(hash);

	for (p = match_tab; p->cm_match; p++) {
		if (p->cm_len < plen && 
		    memcmp(p->cm_pfx, hash, p->cm_len) == 0 &&
		    p->cm_match(pass, hash, priv) == 0)
		    return 0;
	}
	return 1;
}

#define BASICPREF "Basic "
#define BASICLEN (sizeof(BASICPREF)-1)

VCL_BOOL
vmod_match(MOD_CTX sp, struct vmod_priv *priv, VCL_STRING file, VCL_STRING s)
{
	char buf[1024];	
	char lbuf[1024];	
	char *pass;
	int n;
	FILE *fp;
	int rc;

//	openlog("basicauth",LOG_NDELAY|LOG_PERROR|LOG_PID,LOG_AUTHPRIV);
	if (!s || strncmp(s, BASICPREF, BASICLEN))
		return false;
	s += BASICLEN;
	n = base64_decode((const unsigned char *)s, strlen(s),
			  (unsigned char *)buf, sizeof(buf));
	if (n < 0) {
		syslog(LOG_AUTHPRIV|LOG_ERR, "cannot decode %s", s);
		return false;
	} else if (n == sizeof(buf)) {
		syslog(LOG_AUTHPRIV|LOG_ERR, "hash too long");
		return false;
	}
	buf[n] = 0;

//	syslog(LOG_AUTHPRIV|LOG_DEBUG, "%s => %*.*s", s, n, n, buf);
	pass = strchr(buf, ':');
	if (!pass) {
		syslog(LOG_AUTHPRIV|LOG_ERR, "invalid input");
		return false;
	}
	*pass++ = 0;

	fp = fopen(file, "r");
	if (!fp) {
		syslog(LOG_AUTHPRIV|LOG_ERR, "cannot open file %s: %m", file);
		return false;
	}
//	syslog(LOG_AUTHPRIV|LOG_DEBUG, "scanning file %s", file);
	rc = false;
	while (fgets(lbuf, sizeof(lbuf), fp)) {
		char *p, *q;
		for (p = lbuf; *p && (*p == ' ' || *p == '\t'); p++);
		if (*p == '#')
			continue;
		q = p + strlen(p);
		if (q == p)
			continue;
		if (q[-1] == '\n')
			*--q = 0;
		if (!*p)
			continue;
//		syslog(LOG_AUTHPRIV|LOG_DEBUG, "LINE %s", p);
		q = strchr(p, ':');
		if (!q) 
			continue;
		*q++ = 0;
		if (strcmp(p, buf))
			continue;
		rc = match(pass, q, priv) == 0;
//		syslog(LOG_AUTHPRIV|LOG_DEBUG, "user=%s, rc=%d",p,rc);
		break;
	}
	fclose(fp);
	return rc;
}
