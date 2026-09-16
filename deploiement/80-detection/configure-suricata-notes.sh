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
- Local SID range: 9000001-9000033.
- 9000001-9000006: socle plateforme.
- 9000007-9000025: reconnaissance, CVE E2-E14, canary, isolation.
- 9000026-9000029 SNI TLS: E2, E3, E5 et E4.
- 9000030-9000033 global: traversal, methodes HTTP, payloads, ports sensibles.
- Trigger inoffensif: ./trigger-suricata-rules.sh
EOF
