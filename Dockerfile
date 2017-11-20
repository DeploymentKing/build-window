FROM alpine

MAINTAINER SomoGlobal DevOps <devops@somoglobal.com>

ENV PORT 3030
EXPOSE $PORT

RUN apk update && \
    apk upgrade && \
    apk add --no-cache ruby ruby-bundler ruby-dev ruby-json nodejs build-base libstdc++ tzdata bash curl-dev ca-certificates && \
    rm -rf /var/cache/apk/* && \
    echo 'gem: --no-document' > /etc/gemrc && \
    gem install bundler

COPY . /build-window
WORKDIR /build-window
RUN bundle install
