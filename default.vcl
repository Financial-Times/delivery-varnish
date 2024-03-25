vcl 4.0;

import vsthrottle;
import basicauth;
import std;
import saintmode;
import directors;

# Default backend definition. Set this to point to your content server.
backend default {
    .host = "api-policy-component";
    .port = "8080";
}

backend content_notifications_push {
  .host = "notifications-push";
  .port = "8599";
}

backend list_notifications_push {
  .host = "list-notifications-push";
  .port = "8599";
}

backend page_notifications_push {
  .host = "page-notifications-push";
  .port = "8599";
}

backend annotation_notifications_push {
  .host = "annotation-notifications-push";
  .port = "8599";
}

backend health_check_service {
  .host = "upp-aggregate-healthcheck";
  .port = "8080";
  .probe = {
      .url = "/__health";
      .timeout = 1s;
      .interval = 7s;
      .window = 5;
      .threshold = 2;
  }
}

backend health_check_service-second {
  .host = "upp-aggregate-healthcheck-second";
  .port = "8080";
  .probe = {
      .url = "/__health";
      .timeout = 1s;
      .interval = 7s;
      .window = 5;
      .threshold = 2;
  }
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

backend upp_article_validator {
  .host = "upp-article-validator";
  .port = "8080";
}

backend upp_internal_article_validator {
  .host = "upp-internal-article-validator";
  .port = "8080";
}

backend upp_image_validator {
  .host = "upp-image-validator";
  .port = "8080";
}

backend upp_image_set_validator {
  .host = "upp-image-set-validator";
  .port = "8080";
}

backend upp_graphic_validator {
  .host = "upp-graphic-validator";
  .port = "8080";
}

backend upp_list_validator {
  .host = "upp-list-validator";
  .port = "8080";
}

backend upp_content_collection_validator {
  .host = "upp-content-collection-validator";
  .port = "8080";
}

backend upp_internal_content_placeholder_validator {
  .host = "upp-internal-content-placeholder-validator";
  .port = "8080";
}

backend upp_content_placeholder_validator {
  .host = "upp-content-placeholder-validator";
  .port = "8080";
}

backend upp_live_blog_post_validator {
  .host = "upp-live-blog-post-validator";
  .port = "8080";
}

backend upp_audio_validator {
  .host = "upp-audio-validator";
  .port = "8080";
}

backend upp_live_blog_package_validator {
  .host = "upp-live-blog-package-validator";
  .port = "8080";
}

backend upp_internal_live_blog_post_validator {
  .host = "upp-internal-live-blog-post-validator";
  .port = "8080";
}

backend upp_internal_live_blog_package_validator {
  .host = "upp-internal-live-blog-package-validator";
  .port = "8080";
}

backend upp_page_validator {
  .host = "upp-page-validator";
  .port = "8080";
}

backend upp_live_event_validator {
  .host = "upp-live-event-validator";
  .port = "8080";
}

backend upp_schema_reader {
  .host = "upp-schema-reader";
  .port = "8080";
}

backend cm_metadata_quality_api {
  .host = "cm-metadata-quality-api";
  .port = "8080";
}

backend cm_concept_lists_api {
  .host = "cm-concept-lists-api";
  .port = "8080";
}

backend cm_search_api {
  .host = "cm-search-api";
  .port = "8080";
}

backend public_content_relation_api {
  .host = "public-content-relation-api";
  .port = "8080";
}

sub vcl_init {
    # Instantiate sm1, sm2 for backends tile1, tile2
    # with 10 blacklisted objects as the threshold for marking the
    # whole backend sick.
    new health1 = saintmode.saintmode(health_check_service-second, 2);
    new health2 = saintmode.saintmode(health_check_service, 2);

    # Add both to a director. Use sm0, sm1 in place of tile1, tile2.
    # Other director types can be used in place of random.
    new healthdirector = directors.random();
    healthdirector.add_backend(health1.backend(), 1);
    healthdirector.add_backend(health2.backend(), 1);
}

#Add VPC CIDRs for AWS EKS Test and Prod EU/US
acl purge {
    "localhost";
    "10.169.0.0"/18;
    "10.168.0.0"/18;
    "10.169.64.0"/18;
    "10.168.64.0"/18;
}

sub vcl_hash {
    # set cache key to lowercased req.url
    hash_data(std.tolower(req.url));
    return (lookup);
}

sub vcl_recv {
    # Remove all cookies; we don't need them, and setting cookies bypasses varnish caching.
    # Skip removal for /ccf and /portal, the backend needs cookies for authentication
    if ((req.url !~ "^\/ccf\/") && (req.url !~ "^\/portal\/")) {
        unset req.http.Cookie;
    }

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

    // Allow /ccf and /portal to pass without requiring auth. They have authentication of their own.
    if ((req.url ~ "^\/ccf\/") || (req.url ~ "^\/portal\/$") || (req.url ~ "^\/portal\/specs\/") || (req.url ~ "^\/portal\/api\/") || (req.url ~ "^\/portal\/.+(\/|\.ico|\.css|\.html|\.js|\.js\.map|\.json|\.png|\.seq|\.sh|\.sq|\.txt|\.xml)$") || (req.url ~ "^\/portal\/(docs.*|concepts|swagger|query-builder)$")) {
        set req.backend_hint = internal_apps_routing_varnish;
        return (pipe);
    }


    // allow notifications-push health and gtg checks to pass without requiring auth
    if ((req.url ~ "^\/__(annotation-|list-|page-)?notifications-push\/__health.*$") || (req.url ~ "^\/__(annotation-|list-|page-)?notifications-push\/__gtg.*$")) {
        if (req.url ~ "list") {
            set req.backend_hint = list_notifications_push;
        } elseif (req.url ~ "page") {
            set req.backend_hint = page_notifications_push;
        } elseif (req.url ~ "annotation") {
                    set req.backend_hint = annotation_notifications_push;
        } else {
            set req.backend_hint = content_notifications_push;
        }
        set req.url = regsub(req.url, "^\/__[\w-]*\/(.*)$", "/\1");
        return (pass);
    }

    if ((req.url ~ "^\/__health.*$") || (req.url ~ "^\/__gtg.*$")) {
        if ((req.url ~ "^\/__health\/(dis|en)able-category.*$") || (req.url ~ "^\/__health\/.*-ack.*$")) {
            if (!basicauth.match("/etc/varnish/auth/.htpasswd",  req.http.Authorization)) {
                return(synth(401, "Authentication required"));
            }
        }
        set req.backend_hint = healthdirector.backend();
        return (pass);
    }

    if (req.url ~ "^\/(annotations|lists|pages|content)\/notifications-push.*$") {
        if (req.url ~ "^\/annotations\/notifications-push.*$") {
            set req.backend_hint = annotation_notifications_push;
	    } elseif (req.url ~ "^\/pages\/notifications-push.*$") {
            set req.backend_hint = page_notifications_push;
        } elseif (req.url ~ "^\/lists\/notifications-push.*$") {
            set req.backend_hint = list_notifications_push;
        } elseif (req.url ~ "^\/content\/notifications-push.*$") {
            set req.backend_hint = content_notifications_push;
        }
        return (pipe);
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
    } elseif (req.url ~ "^\/content\/validate$") {
        if (req.http.Content-Type ~ "^application\/vnd\.ft-upp-article\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_article_validator;
        } elseif (req.http.Content-Type ~ "^application\/vnd\.ft-upp-article-internal\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_internal_article_validator;
        } elseif (req.http.Content-Type ~ "^application\/vnd\.ft-upp-image\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_image_validator;
        } elseif (req.http.Content-Type ~ "^application\/vnd\.ft-upp-image-set\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_image_set_validator;
        } elseif (req.http.Content-Type ~ "^application\/vnd\.ft-upp-graphic\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_graphic_validator;
        } elseif (req.http.Content-Type ~ "^application\/vnd\.ft-upp-list\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_list_validator;
        } elseif (req.http.Content-Type ~ "^application\/vnd\.ft-upp-content-collection\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_content_collection_validator;
        } elseif (req.http.Content-Type ~ "^application\/vnd\.ft-upp-content-placeholder\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_content_placeholder_validator;
        } elseif (req.http.Content-Type ~ "^application\/vnd\.ft-upp-content-placeholder-internal\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_internal_content_placeholder_validator;
        } else if (req.http.Content-Type ~ "^application\/vnd\.ft-upp-live-blog-post\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_live_blog_post_validator;
        } else if (req.http.Content-Type ~ "^application\/vnd\.ft-upp-live-blog-post-internal\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_internal_live_blog_post_validator;
        } else if (req.http.Content-Type ~ "^application\/vnd\.ft-upp-live-blog-package\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_live_blog_package_validator;
        } else if (req.http.Content-Type ~ "^application\/vnd\.ft-upp-live-blog-package-internal\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_internal_live_blog_package_validator;
        } else if (req.http.Content-Type ~ "^application\/vnd\.ft-upp-audio\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_audio_validator;
        } else if (req.http.Content-Type ~ "^application\/vnd\.ft-upp-page\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_page_validator;
        } else if (req.http.Content-Type ~ "^application\/vnd\.ft-upp-live-event\+json.*$") {
            set req.url = "/validate";
            set req.backend_hint = upp_live_event_validator;
        }
    } elseif (req.url ~ "^\/schemas.*$") {
            set req.backend_hint = upp_schema_reader;
    } elseif (req.url ~ "^\/metadata-quality.*$") {
            set req.url = regsub(req.url, "^\/metadata-quality\/(.*)$", "/\1");
            set req.backend_hint = cm_metadata_quality_api;
    } elseif (req.url ~ "^\/concept\/lists.*$") {
            set req.url = regsub(req.url, "^\/concept\/lists\/(.*)$", "/\1");
            set req.backend_hint = cm_concept_lists_api;
    } elseif (req.url ~ "^\/content\/query.*$") {
            set req.url = regsub(req.url, "^\/content\/query(.*)$", "/search\1");
            set req.backend_hint = cm_search_api;
    } elseif (req.url ~ "^\/relatedcontent\/.*$") {
            set req.backend_hint = public_content_relation_api;
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

    if ((resp.status == 429) || (resp.status == 405)) {
        return (deliver);
    }
}


sub vcl_backend_fetch {
    if ((bereq.backend == healthdirector.backend()) && (bereq.retries > 0)) {
        # Get a backend from the director.
        # When returning a backend, the director will only return backends
        # saintmode says are healthy.
        set bereq.backend = healthdirector.backend();
    }
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.
    if (((beresp.status == 500) || (beresp.status == 502) || (beresp.status == 503) || (beresp.status == 504)) && (bereq.method == "GET" ) && ((beresp.backend.name != health_check_service) || (beresp.backend.name != health_check_service-second))) {
        if (bereq.retries < 2 ) {
            return(retry);
        }
    }

    if (((beresp.status == 500) || (beresp.status == 502) || (beresp.status == 503) || (beresp.status == 504)) && (bereq.method == "GET" ) && ((beresp.backend.name == health_check_service) || (beresp.backend.name == health_check_service-second))) {
        saintmode.blacklist(7s);
        return(retry);
        #if (bereq.retries < 2 ) {
            # This marks the backend as sick for this specific
            # object for the next 20s.
        #    saintmode.blacklist(20s);
            # Retry the request. This will result in a different backend
            # being used.
        #    return(retry);
        #}
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

    # CORS response for smartlogic widget
    if (req.http.Origin == "https://cloud.smartlogic.com" && req.url ~ "(\/content.*|\/concept\/search.*|\/concordances.*)") {
        set resp.http.Access-Control-Allow-Origin = req.http.Origin;
        set resp.http.Access-Control-Allow-Methods = "GET, POST, OPTIONS";
        set resp.http.Access-Control-Allow-Headers = "*";
    }
    if (resp.http.Vary) {
        set resp.http.Vary = resp.http.Vary + ",Origin";
    } else {
        set resp.http.Vary = "Origin";
    }
}
