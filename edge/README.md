# edge — shared nginx + certbot stack

The single reverse proxy / TLS termination point for every project on the server. Not
owned by any one project — projects join its networks as peers via `external: true`, they
don't embed their own nginx/certbot.

Currently serving: `markusheuer.com` / `www.markusheuer.com` (portfolio),
`travelplanner.markusheuer.com` / `dev.markusheuer.com` / `test.markusheuer.com`
(TravelPlanner), `renovationtracker.markusheuer.com` (Renovation Tracker), and
`loopifydemo.markusheuer.com` (Loopify demo).

`dev`/`test` return 502 whenever TravelPlanner's dev/test stacks aren't running.
That's the dynamic-resolver design working as intended rather than a fault — see
the note at the top of `nginx/default.conf.template`.

## Onboarding a new project

A new project's own compose file should **not** define `nginx`/`certbot` services —
those live here instead. Bring it onto this stack in this order (each step depends on the
previous one existing; doing this out of order will break `nginx -t` on the currently-live
container — do not add a server block for a network that doesn't exist yet):

1. **Deploy the project for the first time**, with its own `web-prod` network declared
   as an ordinary (non-external) bridge network in its own compose file — that first
   `docker compose up` is what creates `<project>_web-prod`. Nothing about the edge stack
   changes yet at this point.

2. **Expand the shared cert's SAN list** to cover the new hostname (run inside
   `edge-certbot-1`, requires the new hostname's DNS to already point at this server):
   ```bash
   docker exec edge-certbot-1 certbot certonly --cert-name markusheuer.com-0001 --expand \
     --webroot -w /var/www/certbot \
     -d markusheuer.com -d www.markusheuer.com -d dev.markusheuer.com \
     -d test.markusheuer.com -d travelplanner.markusheuer.com \
     -d <new-hostname> \
     --email markus.kaad.heuer@gmail.com --agree-tos --no-eff-email
   ```
   (List every hostname the cert already covers plus the new one — `--expand` replaces the
   SAN list, it doesn't append to it.)

3. **Add the new project's network as `external: true`** in `docker-compose.yml` here,
   and a server block for the new hostname in `nginx/default.conf.template`.

4. **Recreate the edge nginx container** to pick up both: `docker compose up -d nginx`
   from this directory. Validate first with a dry-run against the real networks (see the
   pattern used for the original TravelPlanner cutover) before doing this against the live
   container, since a config error here takes down every project's hosting, not just the
   new one.

## Smart-Cart (SuperMarketReceiptFinder) — prepared, not yet onboarded

Domain assigned: `smartcart.markusheuer.com`. SMRF's own `nginx`/`certbot` were already
removed from its compose file and its `web-prod` network is ready to be created on first
deploy, but steps 2–4 above haven't happened yet — SMRF isn't deployed anywhere, so there's
no network yet to attach to. The server block to add at step 3, once step 1 has actually
run:

```nginx
server {
    listen      443 ssl;
    listen      [::]:443 ssl;
    http2       on;
    server_name smartcart.markusheuer.com;

    ssl_certificate     /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols             TLSv1.2 TLSv1.3;
    ssl_ciphers               HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache         shared:SSL:10m;
    ssl_session_timeout       1d;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options    "nosniff"                                      always;
    add_header X-Frame-Options           "SAMEORIGIN"                                   always;
    add_header X-XSS-Protection          "1; mode=block"                                always;
    add_header Referrer-Policy           "strict-origin-when-cross-origin"              always;

    location / {
        proxy_pass         http://frontend-prod:3000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade    $http_upgrade;
        proxy_set_header   Connection "upgrade";
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    location /api/ {
        proxy_pass         http://backend-prod:8000/;
        proxy_http_version 1.1;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
```

Note this reuses the `$DOMAIN` variable (already substituted to `markusheuer.com` for the
whole file) for the cert path, since it's the same expanded cert — not a separate
certificate for the subdomain. Also add `smartcart.markusheuer.com` to the HTTP→HTTPS
redirect block's `server_name` line at the top of `default.conf.template`, and add
`supermarketreceiptfinder_web-prod: {external: true}` to this file's `networks:` section
alongside the existing `travelplanner_web-*` entries.

## Renovation Tracker — onboarded

`renovationtracker.markusheuer.com`, DNS cut over from Vercel to this droplet.
Its server block proxies `/auth/v1`, `/rest/v1` and `/storage/v1` to GoTrue,
PostgREST and storage-api respectively (with the path prefix stripped by an
explicit `rewrite`, since a variable `proxy_pass` doesn't do that on its own),
and everything else to the Next.js app.

## Loopify demo — onboarded

`loopifydemo.markusheuer.com`, on the `loopify_web-loopify` network. A single
Next.js container — the demo keeps its flows in memory and calls the model from
its own route handlers, so there's no API/storage split to route around and no
database.

Its `location /` raises `proxy_read_timeout`/`proxy_send_timeout` to 180s.
Flow generation is a model call that can run past nginx's 60s default, and
without that the browser gets a 504 while the request is still in flight
upstream.

Server block to add at step 3, once DNS points here and step 2's cert
expansion has run for `renovationtracker.markusheuer.com`:

```nginx
server {
    listen      443 ssl;
    listen      [::]:443 ssl;
    http2       on;
    server_name renovationtracker.markusheuer.com;

    ssl_certificate     /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols             TLSv1.2 TLSv1.3;
    ssl_ciphers               HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache         shared:SSL:10m;
    ssl_session_timeout       1d;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options    "nosniff"                                      always;
    add_header X-Frame-Options           "SAMEORIGIN"                                   always;
    add_header X-XSS-Protection          "1; mode=block"                                always;
    add_header Referrer-Policy           "strict-origin-when-cross-origin"              always;

    resolver 127.0.0.11 valid=10s ipv6=off;

    location /auth/v1/ {
        set $upstream_rt_auth http://auth:9999/;
        proxy_pass $upstream_rt_auth;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /rest/v1/ {
        set $upstream_rt_rest http://rest:3000/;
        proxy_pass $upstream_rt_rest;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /storage/v1/ {
        set $upstream_rt_storage http://storage:5000/;
        proxy_pass $upstream_rt_storage;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        client_max_body_size 50M;
    }

    location / {
        set $upstream_rt_app http://renovation-tracker:3000;
        proxy_pass $upstream_rt_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade           $http_upgrade;
        proxy_set_header Connection        "upgrade";
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Path-based routing to `/auth/v1`, `/rest/v1`, `/storage/v1` here replaces
the Kong gateway a full Supabase stack would normally run, matching the
approach documented in renovation-tracker's own docker-compose.yml. Also
add `renovationtracker.markusheuer.com` to the HTTP->HTTPS redirect
block's `server_name` line, and
`renovation-tracker_web-renovationtracker: {external: true}` to this
file's `networks:` section.
