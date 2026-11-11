#!/usr/bin/env bash
# There is already a one-click installer and a release here; I just haven't had
# time to test them yet.
# No matter how this project turns out, people will still mock and insult me.
# I won't make promises to anyone anymore. My commitments to this project have
# brought me nothing in return and have instead become a burden.
# Once I started treating it as my own toy project, everything became much easier.
# I don't have to answer to anyone.
# If you're planning to save the world, please leave me out of it.
# I need to go save my own world first.
#
# Small raw-GitHub entry point. A complete, verified release installer does the work.
set -euo pipefail

main() (
    set -euo pipefail
    local command metadata tag pattern temporary hash filename expected='' found=0
    local distro_id='' distro_like='' local_installer=''

    # Ubuntu/Debian releases have no Arch package installer. Build from source
    # with the repository's native ARM64 installer instead of falling through
    # to the Arch release download below.
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        distro_id=${ID:-}
        distro_like=${ID_LIKE:-}
        case " $distro_id $distro_like " in
            *ubuntu*|*debian*)
                for command in curl sha256sum mktemp bash git; do
                    command -v "$command" >/dev/null || {
                        printf 'Required command: %s\n' "$command" >&2
                        return 1
                    }
                done
                if [[ -n ${BASH_SOURCE[0]:-} ]]; then
                    local_installer="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/install-ubuntu.sh"
                fi
                if [[ -f $local_installer ]]; then
                    exec bash "$local_installer" "$@"
                fi
                temporary=$(mktemp -d "${TMPDIR:-/tmp}/clavis-ubuntu-source.XXXXXX")
                trap 'rm -rf -- "$temporary"' EXIT
                git clone --depth 1 --branch main https://github.com/StatIndet/quickshell.git \
                    "$temporary/quickshell" >/dev/null 2>&1 || {
                    printf 'Could not download the Clavis source tree.\n' >&2
                    return 1
                }
                exec bash "$temporary/quickshell/install-ubuntu.sh" "$@"
                ;;
        esac
    fi

    for command in curl sha256sum mktemp bash; do
        command -v "$command" >/dev/null || { printf 'Required command: %s\n' "$command" >&2; return 1; }
    done
    temporary=$(mktemp -d "${TMPDIR:-/tmp}/clavis-bootstrap.XXXXXX")
    trap 'rm -rf -- "$temporary"' EXIT
    metadata=$(curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
        https://api.github.com/repos/StatIndet/quickshell/releases/latest)
    pattern='"tag_name"[[:space:]]*:[[:space:]]*"(v[0-9]{4}\.[0-9]{1,2}\.[0-9]{1,2}(\.[0-9]+)?)"'
    [[ $metadata =~ $pattern ]] || { printf 'No completed Clavis date release is available.\n' >&2; return 1; }
    tag=${BASH_REMATCH[1]}
    local base="https://github.com/StatIndet/quickshell/releases/download/$tag"
    for filename in SHA256SUMS install-arch.sh; do
        curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
            "$base/$filename" --output "$temporary/$filename"
    done
    while read -r hash filename; do
        if [[ $filename == install-arch.sh && $hash =~ ^[0-9a-f]{64}$ ]]; then
            expected=$hash
            found=$((found + 1))
        fi
    done < "$temporary/SHA256SUMS"
    [[ $found == 1 ]] || { printf 'Release installer checksum is missing or ambiguous.\n' >&2; return 1; }
    (cd "$temporary" && printf '%s  install-arch.sh\n' "$expected" | sha256sum --check --status) || {
        printf 'Release installer checksum mismatch.\n' >&2; return 1;
    }
    bash "$temporary/install-arch.sh" "$@"
)

main "$@"
