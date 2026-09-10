# syntax=docker/dockerfile:1

ARG AWSCLI_VERSION=2.36.39
ARG HELM_VERSION=4.2.3
ARG GO_VERSION=1.27
ARG KUBECTL_VERSION=1.35
ARG PYTHON_VERSION=3.12
ARG YQ_VERSION=4.53.6

ARG CERT_URL=https://raw.githubusercontent.com/cfpb/zscaler-cert/3982ebd9edf9de9267df8d1732ff5a6f88e38375/zscaler_root_ca.pem

FROM scratch AS certs

ARG CERT_URL
ADD --chmod=644 ${CERT_URL} /zscaler-root-public.crt

FROM python:${PYTHON_VERSION}-alpine AS awscli-builder

ARG AWSCLI_VERSION

ENV BASE_HOME=/usr/home

COPY --from=certs /zscaler-root-public.crt /usr/local/share/ca-certificates/
RUN cat /usr/local/share/ca-certificates/zscaler-root-public.crt >> /etc/ssl/certs/ca-certificates.crt

RUN apk add --no-cache git build-base libffi-dev openssl-dev cargo

RUN git clone \
    --depth 1 \
    --branch ${AWSCLI_VERSION} \
    https://github.com/aws/aws-cli.git \
    /src

WORKDIR /src

RUN python -m venv /opt/aws-venv \
    && /opt/aws-venv/bin/pip install --no-cache-dir -U pip \
    && /opt/aws-venv/bin/pip install --no-cache-dir .

FROM golang:${GO_VERSION}-alpine AS yq-builder

ARG YQ_VERSION

ENV BASE_HOME=/usr/home
ENV CGO_ENABLED=0

COPY --from=certs /zscaler-root-public.crt /usr/local/share/ca-certificates/
RUN cat /usr/local/share/ca-certificates/zscaler-root-public.crt >> /etc/ssl/certs/ca-certificates.crt

RUN go install github.com/mikefarah/yq/v4@v${YQ_VERSION}

FROM python:${PYTHON_VERSION}-alpine AS tools

ARG HELM_VERSION
ARG KUBECTL_VERSION
ARG TARGETARCH

ENV BASE_HOME=/usr/home

COPY --from=certs /zscaler-root-public.crt /usr/local/share/ca-certificates/
RUN cat /usr/local/share/ca-certificates/zscaler-root-public.crt >> /etc/ssl/certs/ca-certificates.crt

RUN apk add --no-cache curl

RUN curl -fsSLO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
    && curl -fsSLO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz.sha256sum" \
    && sha256sum -c "helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz.sha256sum" \
    && tar -xzvf "helm-v${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
    && mv "linux-${TARGETARCH}/helm" /opt/helm

RUN KUBECTL_RELEASE="$(curl -fsSL "https://dl.k8s.io/release/stable-${KUBECTL_VERSION}.txt")" \
    && echo "Resolved kubectl ${KUBECTL_VERSION} to ${KUBECTL_RELEASE}." \
    && curl -fsSLo /opt/kubectl "https://dl.k8s.io/release/${KUBECTL_RELEASE}/bin/linux/${TARGETARCH}/kubectl" \
    && curl -fsSLo kubectl.sha256 "https://dl.k8s.io/release/${KUBECTL_RELEASE}/bin/linux/${TARGETARCH}/kubectl.sha256" \
    && echo "$(cat kubectl.sha256) /opt/kubectl" | sha256sum -c - \
    && chmod +x /opt/kubectl

FROM python:${PYTHON_VERSION}-alpine

ENV AWS_PAGER=""
ENV BASE_HOME=/usr/home
ENV LANG=en_US.UTF-8
ENV PIP_NO_CACHE_DIR=true
ENV PYTHONUNBUFFERED=1

COPY --from=certs /zscaler-root-public.crt /usr/local/share/ca-certificates/
RUN cat /usr/local/share/ca-certificates/zscaler-root-public.crt >> /etc/ssl/certs/ca-certificates.crt

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
    PIP_CERT=/etc/ssl/certs/ca-certificates.crt

RUN apk add --no-cache bash curl git jq

COPY --from=awscli-builder /opt/aws-venv /opt/aws-venv
RUN ln -s /opt/aws-venv/bin/aws /usr/local/bin/aws
COPY --from=yq-builder /go/bin/yq /usr/local/bin/yq
COPY --from=tools /opt/helm /usr/local/bin/helm
COPY --from=tools /opt/kubectl /usr/local/bin/kubectl

RUN pip install --no-cache-dir -U pip \
    && pip install --no-cache-dir boto3 psycopg[binary]

# Don't run as the root user.
WORKDIR ${BASE_HOME}
RUN adduser -g "base" --disabled-password base

USER base
