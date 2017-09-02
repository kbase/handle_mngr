FROM bitnami/minideb:stretch
MAINTAINER Steve Chan sychan@lbl.gov

# These ARGs values are passed in via the docker build command
ARG BUILD_DATE
ARG VCS_REF
ARG BRANCH=develop

# Shinto-cli is a jinja2 template cmd line tool
RUN apt-get update -y && \
    apt-get install -y ca-certificates cpanminus python-minimal python-pip openssl wget && \
    update-ca-certificates && \
    pip install shinto-cli[yaml] && \
    cpanm HTTP::Request LWP::UserAgent JSON Exception::Class Config::Simple Object::Tiny::RW \
          starman

# Setup the base perl libs
CMD mkdir -p /kb/deployment/lib
ENV PERL5LIB /kb/deployment/lib
COPY deployment/lib /kb/deployment/lib

# The BUILD_DATE value seem to bust the docker cache when the timestamp changes, move to
# the end
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-url="https://github.com/kbase/handle_mngr.git" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.schema-version="1.0.0-rc1" \
      us.kbase.vcs-branch=$BRANCH
