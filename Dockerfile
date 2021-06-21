FROM ubuntu:latest as vaccel-release
#ENV DEBIAN_FRONTEND="noninteractive"
#RUN apt-get update && apt-get install -y wget unzip
#RUN wget https://github.com/cloudkernels/vaccel/releases/download/latest/vaccel_x86_64_Release.zip && \
#    unzip vaccel_x86_64_Release.zip -d /vaccel
COPY vaccel-Release/opt/ /vaccel



FROM ubuntu:latest as builder

COPY --from=vaccel-release /vaccel/lib/libvaccel* /usr/local/lib/
COPY --from=vaccel-release /vaccel/include/. /usr/local/include/
COPY --from=vaccel-release /vaccel/share/vaccel.pc /usr/local/share/

RUN git clone https://github.com/nubificus/stdinout.git -b aarch64 && \
    cd stdinout && \
    make


RUN apt-get update && apt-get install -y \
        gcc
RUN git clone https://github.com/nubificus/stdinout -b aarch64

WORKDIR ./stdinout
RUN make

FROM debian:buster-slim
ARG APP=/usr/src/app
RUN apt-get update \
    && apt-get install -y ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/*
EXPOSE 3030
ENV TZ=Etc/UTC \
    APP_USER=appuser
RUN groupadd $APP_USER \
    && useradd -g $APP_USER $APP_USER \
    && mkdir -p ${APP}
COPY --from=vaccel-release /vaccel/lib/libvaccel.so /lib/
COPY --from=vaccel-release /vaccel/lib/libvaccel-vsock.so /lib/
RUN chown -R $APP_USER:$APP_USER ${APP}
RUN mkdir /run/user
RUN chmod go+rwX /run/user
USER $APP_USER
WORKDIR ${APP}
ENV RUST_LOG=debug
CMD ["./web-classify"]

FROM functions/alpine:latest

COPY test_static /test

FROM ghcr.io/openfaas/classic-watchdog:0.1.4 as watchdog

FROM ubuntu:20.04

RUN mkdir -p /home/app

COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
RUN chmod +x /usr/bin/fwatchdog

# Add non root user
RUN adduser app && adduser app app
RUN chown app /home/app

WORKDIR /home/app

USER app


COPY --from=builder /stdinout/test /test
COPY --from=builder /stdinout/libfileread.so /lib
COPY --from=builder /usr/local/lib/libvaccel* /lib/

ENV LD_LIBRARY_PATH=/lib/
ENV VACCEL_BACKENDS=/lib/libvaccel-vsock.so 
ENV VACCEL_VSOCK=vsock://2:2048
ENV VACCEL_DEBUG_LEVEL=4

EXPOSE 8080

HEALTHCHECK --interval=3s CMD [ -e /tmp/.lock ] || exit 1

CMD ["fwatchdog"]
