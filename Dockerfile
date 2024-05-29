ARG GOLANG_VERSION=1.22

# Build image
FROM golang:${GOLANG_VERSION}-alpine as build

LABEL org.opencontainers.image.source="https://github.com/writefreely/writefreely"
LABEL org.opencontainers.image.description="WriteFreely is a clean, minimalist publishing platform made for writers. Start a blog, share knowledge within your organization, or build a community around the shared act of writing."

ARG WRITEFREELY_VERSION=v0.15.0
ARG WRITEFREELY_FORK=writefreely/writefreely

RUN apk -U upgrade \
    && apk add --no-cache nodejs npm make g++ git sqlite-dev \
    && npm install -g less less-plugin-clean-css \
    && mkdir -p /go/src/github.com/writefreely/writefreely
RUN npm install -g less less-plugin-clean-css

RUN mkdir -p /go/src/github.com/${WRITEFREELY_FORK}
RUN git clone https://github.com/${WRITEFREELY_FORK}.git /go/src/github.com/${WRITEFREELY_FORK} -b ${WRITEFREELY_VERSION}
WORKDIR /go/src/github.com/${WRITEFREELY_FORK}

ENV GO111MODULE=on
ENV NODE_OPTIONS=--openssl-legacy-provider

RUN make build \
  && make ui

RUN mkdir /stage && \
  cp -R /go/bin \
  /go/src/github.com/${WRITEFREELY_FORK}/templates \
  /go/src/github.com/${WRITEFREELY_FORK}/static \
  /go/src/github.com/${WRITEFREELY_FORK}/pages \
  /go/src/github.com/${WRITEFREELY_FORK}/keys \
  /go/src/github.com/${WRITEFREELY_FORK}/cmd \
  /stage && \
  mv /stage/cmd/writefreely/writefreely /stage

# Final image
FROM alpine:3.19

ARG WRITEFREELY_UID=1000
ARG WRITEFREELY_GID=1000

RUN apk -U upgrade && apk add --no-cache openssl ca-certificates

RUN addgroup -g ${WRITEFREELY_GID} -S writefreely && adduser -u ${WRITEFREELY_UID} -S -G writefreely writefreely

COPY --from=build --chown=daemon:daemon /stage /writefreely
COPY bin/writefreely-docker.sh /writefreely/

WORKDIR /writefreely
VOLUME /data
EXPOSE 8080

RUN chown -R writefreely:writefreely /writefreely

USER writefreely

ENTRYPOINT ["/writefreely/writefreely-docker.sh"]

