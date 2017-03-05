FROM alpine:latest

RUN apk add --update bash && rm -rf /var/cache/apk/*

COPY run.sh /run.sh

CMD ["/run.sh"]
