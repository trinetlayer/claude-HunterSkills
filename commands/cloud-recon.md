---
description: Map an authorized cloud footprint — buckets, origin IP, exposed creds/services (read-only first).
argument-hint: <company/domain or cloud account you're authorized to assess>
allowed-tools: Bash, Read, Grep
---

Cloud recon for: `$ARGUMENTS`

Load the **cloud-pentest** skill and confirm authorization first. Then map the read-only surface:
public S3/GCS/Azure buckets, Cloudflare origin-IP behind the CDN, live-but-unknown cloud creds
(`sts get-caller-identity`, read-only permission enum), and exposed K8s/Docker/etcd services. Keep to
enumeration + read-only validation; anything write/privesc needs explicit scope. Findings must climb the
Validation Ladder before reporting.
