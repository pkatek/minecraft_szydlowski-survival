FROM itzg/minecraft-server:java25

LABEL org.opencontainers.image.title="Szydlowski Survival"
LABEL org.opencontainers.image.description="Minecraft Java Paper server"

COPY scripts/ /plugins/Skript/scripts/
COPY config/scoreboards.yml /plugins/SimpleScore/scoreboards.yml
