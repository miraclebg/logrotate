FROM alpine AS build-gocron

MAINTAINER Martin Kovachev <miracle@nimasystems.com>

WORKDIR /build

RUN apk add --update \
    git go
RUN git clone https://github.com/michaloo/go-cron.git \
    && cd go-cron \
    && go mod init gocron \
    && go mod tidy \
    && go build -o go-cron ./go-cron.go

FROM alpine

MAINTAINER Martin Kovachev <miracle@nimasystems.com>
MAINTAINER Steffen Bleul <sbl@blacklabelops.com>

# logrotate version (e.g. 3.9.1-r0)
ARG LOGROTATE_VERSION=latest
# permissions
ARG CONTAINER_UID=1000
ARG CONTAINER_GID=1000

# install dev tools
RUN export CONTAINER_USER=logrotate && \
    export CONTAINER_GROUP=logrotate && \
    addgroup -g $CONTAINER_GID logrotate && \
    adduser -u $CONTAINER_UID -G logrotate -h /usr/bin/logrotate.d -s /bin/bash -S logrotate && \
    apk add --update \
      tar \
      gzip \
      wget \
      bash \
      tini \
      tzdata && \
    if  [ "${LOGROTATE_VERSION}" = "latest" ]; \
      then apk add logrotate ; \
      else apk add "logrotate=${LOGROTATE_VERSION}" ; \
    fi && \
    mkdir -p /usr/bin/logrotate.d && \
    apk del \
      wget && \
    rm -rf /var/cache/apk/* && rm -rf /tmp/*

COPY --from=build-gocron /build/go-cron/go-cron /usr/bin/go-cron

# environment variable for this container
ENV LOGROTATE_OLDDIR= \
    LOGROTATE_COMPRESSION= \
    LOGROTATE_INTERVAL= \
    LOGROTATE_COPIES= \
    LOGROTATE_SIZE= \
    LOGS_DIRECTORIES= \
    LOG_FILE_ENDINGS= \
    LOGROTATE_LOGFILE= \
    LOGROTATE_CRONSCHEDULE= \
    LOGROTATE_PARAMETERS= \
    LOGROTATE_STATUSFILE= \
    LOG_FILE=

COPY docker-entrypoint.sh /usr/bin/logrotate.d/docker-entrypoint.sh
COPY update-logrotate.sh /usr/bin/logrotate.d/update-logrotate.sh
COPY logrotate.sh /usr/bin/logrotate.d/logrotate.sh
COPY logrotateConf.sh /usr/bin/logrotate.d/logrotateConf.sh
COPY logrotateCreateConf.sh /usr/bin/logrotate.d/logrotateCreateConf.sh

ENTRYPOINT ["/sbin/tini","--","/usr/bin/logrotate.d/docker-entrypoint.sh"]
VOLUME ["/logrotate-status"]
CMD ["cron"]
