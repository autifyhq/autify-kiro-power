# The testbox: one Chrome on a virtual screen, connected to Aximo as a local device.
# Aximo only ever sees this screen. The developer keeps their own.
ARG PLAYWRIGHT_TAG=v1.62.1-noble
FROM mcr.microsoft.com/playwright:${PLAYWRIGHT_TAG}

RUN apt-get update && apt-get install -y --no-install-recommends \
      socat xvfb x11-utils xauth x11vnc fluxbox novnc websockify curl \
    && rm -rf /var/lib/apt/lists/*

# Chrome's "Save password?" / "Save card?" / "Turn on sync?" bubbles land on top of
# the page and eat the next keystroke Aximo types. A managed policy turns them off.
COPY policies.json /etc/chromium/policies/managed/aximo-testbox.json
RUN node -e 'JSON.parse(require("fs").readFileSync("/etc/chromium/policies/managed/aximo-testbox.json","utf8"))'

COPY entrypoint.sh /usr/local/bin/aximo-testbox-entrypoint
RUN chmod +x /usr/local/bin/aximo-testbox-entrypoint

ENTRYPOINT ["/usr/local/bin/aximo-testbox-entrypoint"]
CMD ["sleep", "infinity"]
