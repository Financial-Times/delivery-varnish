vcl 4.0;

import vsthrottle;
import basicauth;
import std;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "api-policy-component";
    .port = "8080";
}

backend content_notifications_push {
  .host = "notifications-push";
  .port = "8599";
}

backend health_check_service {
  .host = "upp-aggregate-healthcheck";
  .port = "8080";
}

backend public_content_by_concept_api {
  .host = "public-content-by-concept-api";
  .port = "8080";
}

backend internal_apps_routing_varnish {
  .host = "path-routing-varnish";
  .port = "80";
}

backend content_search_api_port {
  .host = "content-search-api-port";
  .port = "8080";
}

backend concept_search_api {
  .host = "concept-search-api";
  .port = "8080";
}

backend public_suggestions_api {
  .host = "public-suggestions-api";
  .port = "8080";
}

acl purge {
    "localhost";
    "10.2.0.0"/16;
}

sub exploit_workaround_4_1 {
    # This needs to come before your vcl_recv function
    # The following code is only valid for Varnish Cache and
    # Varnish Cache Plus versions 4.1.x and 5.0.0
    if (req.http.transfer-encoding ~ "(?i)chunked") {
        C{
        struct dummy_req {
            unsigned magic;
            int step;
            int req_body_status;
        };
        ((struct dummy_req *)ctx->req)->req_body_status = 5;
        }C

        return (synth(503, "Bad request"));
    }
}

sub vcl_hash {
    # set cache key to lowercased req.url
    hash_data(std.tolower(req.url));
    return (lookup);
}

sub vcl_recv {
    call exploit_workaround_4_1;

    # Remove all cookies; we don't need them, and setting cookies bypasses varnish caching.
    unset req.http.Cookie;

    # allow PURGE from localhost and 10.2...
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return(synth(405,"Not allowed."));
        }
        return (purge);
    }

    if (req.url ~ "^\/robots\.txt$") {
        return(synth(200, "robots"));
    }

    if ((!req.http.X-Original-Request-URL) && req.http.X-Forwarded-For && req.http.Host) {
        set req.http.X-Original-Request-URL = "https://" + req.http.Host + req.url;
    }

    //dedup leading slashes
    set req.url = regsub(req.url, "^\/+(.*)$","/\1");

    // allow notifications-push health and gtg checks to pass without requiring auth
    if ((req.url ~ "^\/__notifications-push/__health.*$") || (req.url ~ "^\/__notifications-push/__gtg.*$")) {
        set req.url = regsub(req.url, "^\/__[\w-]*\/(.*)$", "/\1");
        set req.backend_hint = content_notifications_push;
        return (pass);
    }

    if ((req.url ~ "^\/__health.*$") || (req.url ~ "^\/__gtg.*$")) {
        if ((req.url ~ "^\/__health\/(dis|en)able-category.*$") || (req.url ~ "^\/__health\/.*-ack.*$")) {
            if (!basicauth.match("/etc/varnish/auth/.htpasswd",  req.http.Authorization)) {
                return(synth(401, "Authentication required"));
            }
        }
        set req.backend_hint = health_check_service;
        return (pass);
    }

    if ((req.url ~ "^\/content-preview.*$") || (req.url ~ "^\/internalcontent-preview.*$")) {
        if (vsthrottle.is_denied(client.identity, 2, 1s)) {
    	    # Client has exceeded 2 reqs per 1s
    	    return (synth(429, "Too Many Requests"));
        }
    } elseif (req.url ~ "^\/content\/notifications-push.*$") {
        set req.backend_hint = content_notifications_push;
    } elseif (req.url ~ "\/content\?.*isAnnotatedBy=.*") {
        set req.backend_hint = public_content_by_concept_api;
    } elseif (req.url ~ "\/concept\/search.*$") {
        set req.backend_hint = concept_search_api;
    } elseif (req.url ~ "\/content\/suggest/__gtg") {
        set req.url = "/__gtg";
        set req.backend_hint = public_suggestions_api;
    } elseif (req.url ~ "\/content\/suggest.*$") {
        set req.backend_hint = public_suggestions_api;
    } elseif (req.url ~ "\/content\/search.*$") {
        set req.url = regsub(req.url, "^\/content\/(.*)$", "/\1");
        set req.backend_hint = content_search_api_port;
    }

    if (!basicauth.match("/etc/varnish/auth/.htpasswd",  req.http.Authorization)) {
        return(synth(401, "Authentication required"));
    }

    unset req.http.Authorization;
    # We need authentication for internal apps, and no caching, and the authentication should not be passed to the internal apps.
    # This is why this line is after checking the authentication and unsetting the authentication header.
    if (req.url ~ "^\/__[\w-]*\/.*$") {
        set req.backend_hint = internal_apps_routing_varnish;
        return (pipe);
    }
}

sub vcl_synth {
    if (resp.reason == "robots") {
        synthetic({"User-agent: *
Disallow: /"});
        return (deliver);
    }
    if (resp.status == 401) {
        set resp.http.WWW-Authenticate = "Basic realm=Secured";
        set resp.status = 401;
        return (deliver);
    }
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.
    if (((beresp.status == 500) || (beresp.status == 502) || (beresp.status == 503) || (beresp.status == 504)) && (bereq.method == "GET" )) {
        if (bereq.retries < 2 ) {
            return(retry);
        }
    }

    if (beresp.status == 301 && ((beresp.http.cache-control !~ "s-maxage") || (beresp.http.cache-control !~ "max-age"))){
        set beresp.ttl = 31536000s;
    }
}

sub vcl_deliver {
    # Happens when we have all the pieces we need, and are about to send the
    # response to the client.
    #
    # You can do accounting or modifying the final object here.
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }
}
