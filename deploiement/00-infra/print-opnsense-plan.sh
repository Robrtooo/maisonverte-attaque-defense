#!/usr/bin/env bash
# deploiement/00-infra/print-opnsense-plan.sh
#
# Prints the OPNsense NAT/hosts plan a human operator applies by hand: E1,
# the VLANs, routing, NAT and filtering are configured manually (see
# ARCHITECTURE.md: "Les scripts ne font qu'imprimer le plan et verifier le
# resultat."). This script only prints text to stdout. It never calls the
# OPNsense API, never opens an SSH session and never runs `configctl` or
# any other mutating command. Any argument is refused and the refusal is
# logged.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

if [[ $# -gt 0 ]]; then
  mv_die "print-opnsense-plan.sh is read-only and never modifies OPNsense: refus de l'argument: $*"
fi

WAN_PUBLIC="10.85.4.10:443"
LAN_TARGET="192.168.10.50:443"

cat <<PLAN
=== MaisonVerte -- plan OPNsense (application manuelle) ===

NAT (port forward, unique publication externe) :
  ${WAN_PUBLIC} -> ${LAN_TARGET}

Lignes /etc/hosts a distribuer (Document Attaquant) vers 10.85.4.10 :
  10.85.4.10 shop.maisonverte.fr
  10.85.4.10 api.maisonverte.fr
  10.85.4.10 vendeurs.maisonverte.fr
  10.85.4.10 cache.maisonverte.fr

Rappel : ce script n'applique aucune regle. La configuration OPNsense
(VLAN, routage, NAT, filtrage) reste manuelle ; utilisez verify-opnsense.sh
pour un controle read-only une fois la configuration appliquee.
PLAN

mv_log "refus de modifier OPNsense : ce script est en lecture seule (print-only)"
