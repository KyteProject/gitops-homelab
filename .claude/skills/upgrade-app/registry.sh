#!/usr/bin/env bash
# Query container registries with curl and jq only.
#
# `crane` (from google/go-containerregistry) is the usual tool for this and is
# what the upstream home-ops skills reach for, but it is not installed on this
# machine and is not in just/resources/Brewfile. These functions cover what the
# skills actually need: list tags, and resolve a tag to its digest.
#
#   source .claude/skills/upgrade-app/registry.sh
#   reg_tags   ghcr.io/bjw-s-labs/helm/app-template | tail -5
#   reg_digest docker.io/clidey/whodb 0.127.0
#   reg_exists ghcr.io/actualbudget/actual-server 26.9.0
#
# Verified against docker.io, ghcr.io and quay.io. Anonymous pull only; a
# private repository needs a real token in the Authorization header instead.

reg_split() { # <ref> -> "<host> <repo>"
  local ref="$1" host repo
  case "$ref" in
    */*/*) host="${ref%%/*}"; repo="${ref#*/}" ;;
    */*)   host="docker.io";  repo="$ref" ;;
    *)     host="docker.io";  repo="library/$ref" ;;
  esac
  [[ "$host" == "docker.io" ]] && host="registry-1.docker.io"
  case "$repo" in */*) ;; *) repo="library/$repo" ;; esac
  echo "$host" "$repo"
  return 0
}

reg_token() { # <host> <repo>
  local host="$1" repo="$2" realm
  case "$host" in
    registry-1.docker.io) realm="https://auth.docker.io/token?service=registry.docker.io" ;;
    ghcr.io)              realm="https://ghcr.io/token?service=ghcr.io" ;;
    quay.io)              realm="https://quay.io/v2/auth?service=quay.io" ;;
    *)                    realm="https://$host/token?service=$host" ;;
  esac
  curl -fsS "$realm&scope=repository:$repo:pull" | jq -r '.token // .access_token // empty'
  return 0
}

# Tags, cosign artefacts stripped, version sorted.
reg_tags() { # <ref>
  local ref="$1"
  local host repo tok
  read -r host repo < <(reg_split "$ref")
  tok=$(reg_token "$host" "$repo")
  curl -fsS -H "Authorization: Bearer $tok" "https://$host/v2/$repo/tags/list?n=1000" |
    jq -r '.tags[]' | grep -Ev '^sha256-|\.(sig|att|sbom)$' | sort -V
  return 0
}

# Digest for one tag, for the `tag@sha256:...` form the manifests use.
reg_digest() { # <ref> <tag>
  local ref="$1" tag="$2"
  local host repo tok
  read -r host repo < <(reg_split "$ref")
  tok=$(reg_token "$host" "$repo")
  curl -fsSI -H "Authorization: Bearer $tok" \
    -H 'Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json' \
    "https://$host/v2/$repo/manifests/$tag" | tr -d '\r' |
    awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}'
  return 0
}

# True if the tag exists. This is the "confirm before landing" check.
# Quiet on a missing tag, so it reads as a plain conditional.
reg_exists() { # <ref> <tag>
  local ref="$1" tag="$2"
  local digest
  digest=$(reg_digest "$ref" "$tag" 2>/dev/null)
  [[ -n "$digest" ]] && return 0
  return 1
}
