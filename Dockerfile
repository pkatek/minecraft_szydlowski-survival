FROM itzg/minecraft-server:java25

LABEL org.opencontainers.image.title="Szydlowski Survival"
LABEL org.opencontainers.image.description="Minecraft Java Paper server"

ENV ICON=/opt/minecraft/server-icon.png \
    OVERRIDE_ICON=TRUE \
    INIT_MEMORY=1G \
    STOP_DURATION=90 \
    CFG_CLAIM_BLOCK_PRICE=10.0 \
    PRE_START_SCRIPT=/opt/minecraft/configure-claims.sh

HEALTHCHECK --start-period=5m --interval=30s --timeout=10s --retries=5 CMD mc-health

COPY server-icon.png /opt/minecraft/server-icon.png
COPY scripts/*.sk /plugins/Skript/scripts/
COPY config/scoreboards.yml /plugins/SimpleScore/scoreboards.yml
COPY config/griefprevention-economy.json /opt/minecraft/griefprevention-economy.json
COPY --chmod=755 scripts/configure-claims.sh /opt/minecraft/configure-claims.sh
