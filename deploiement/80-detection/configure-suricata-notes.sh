#!/usr/bin/env bash
# Print NSM configuration notes. OPNsense/VLAN/Suricata bridge stay manual.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
. "$SCRIPT_DIR/../lib/common.sh"

cat <<'EOF'
[MaisonVerte] NSM / Suricata scope
- NSM admin: http://192.168.10.30:5636
- Bridge L2: traffic poste/interne-nord -> vulndb/interne-sud inspected.
- Docker intra-host bridge traffic on vulndb may not cross NSM bridge.
- Use ELK for application/container logs, Suricata/EveBox for LAN flows.
- Suggested local SID range: 9000001-9000999.
- Priority detections:
  9000001 E2 traversal /files/../
  9000002 E3 PHPMailer suspicious POST
  9000003 E5 Tomcat PUT JSP
  9000004 E7 Elasticsearch Groovy script
  9000005 E8 Redis SLAVEOF/CONFIG
  9000006 E14 Jenkins CLI /jnlpJars/jenkins-cli.jar
  9000007 E12 XXL-JOB unauth actuator/admin
  9000008 E11 mongo-express RCE payload
  9000009 E6 OFBiz XML-RPC auth bypass
  9000010 E9 SMB write shared object / CVE-2017-7494
  9000011 E13 Struts2 Content-Type OGNL
EOF
