#!/bin/sh
# Read-only diagnostics. Run on the Docker host, not inside the container.
set -eu

if [ "$#" -gt 1 ]; then
    printf 'Usage: sh %s [container-name-or-id]\n' "$0" >&2
    exit 2
fi
container=${1:-szydlowski-survival}
case "$container" in
    ''|-*) printf 'Provide a container name or ID.\n' >&2; exit 2 ;;
esac

if ! command -v docker >/dev/null 2>&1; then
    printf 'Docker is unavailable. Run this script on the server host.\n' >&2
    exit 1
fi

printf '\nContainer state, restart policy and memory limit (bytes):\n'
if ! docker inspect --format 'Name={{.Name}}
State={{json .State}}
RestartCount={{.RestartCount}}
RestartPolicy={{json .HostConfig.RestartPolicy}}
MemoryLimit={{.HostConfig.Memory}}
Mounts={{json .Mounts}}' "$container"; then
    printf '\nCheck the container name and Docker permissions: docker ps -a\n' >&2
    exit 1
fi

printf '\nCurrent resource usage (not historical):\n'
docker stats --no-stream "$container" || true

# Capture an end time so docker events cannot wait indefinitely for new events.
until_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
printf '\nRecent container events (if still retained by Docker):\n'
docker events --since 2h --until "$until_time" \
    --filter "container=$container" --format '{{json .}}' || true

printf '\nLast 200 log lines:\n'
docker logs --timestamps --tail 200 "$container" 2>&1 || true

printf '\nDocker host resources:\n'
docker info --format 'MemoryTotal={{.MemTotal}} CPUs={{.NCPU}} DockerRootDir={{.DockerRootDir}}' || true
if command -v free >/dev/null 2>&1; then
    free -h || true
fi
df -h
