I would not migrate all 40 Ingress objects at the same time. Since the requirement is no downtime, I would do the migration step by step and keep ingress-nginx running until the new setup is fully tested.

First, I would check all the existing Ingress objects and understand what they are using, mainly hostnames, paths, TLS certificates, redirects, rewrites and ingress-nginx-specific annotations. Some nginx annotations may not have a direct replacement in Gateway API, so I would identify those before starting the migration.

Next, I would install a Gateway API compatible controller alongside the existing ingress-nginx controller. I would configure the required GatewayClass and Gateway, and then start converting the existing Ingress rules into HTTPRoute resources.

I would start with one simple and low-risk application. I would test the new route properly, including application access, paths, TLS, redirects and health checks, before moving any actual traffic.

Once it is working correctly, I would gradually move traffic to the new Gateway and monitor errors, logs and latency. If something goes wrong, ingress-nginx would still be available, so I can quickly move the traffic back.

After that, I would migrate the remaining applications in small batches. I would expect some issues mainly around nginx-specific annotations, regex paths, rewrites, TLS and timeout settings.

Once all routes are migrated, tested and stable, I would remove the old Ingress resources and finally decommission ingress-nginx.