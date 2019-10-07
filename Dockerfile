FROM ruby:2.5-stretch

RUN apt-get update

COPY Gemfile /Gemfile

# 1. Install & configure dependencies.
# 2. Install fluentd via ruby.
# 3. Remove build dependencies.
# 4. Cleanup leftover caches & files.
RUN BUILD_DEPS="make gcc g++ libc6-dev" \
    && apt-get install -y $BUILD_DEPS \
                        ca-certificates \
                        libjemalloc1 \
                        liblz4-1 \
    && echo 'gem: --no-document' >> /etc/gemrc \
    && gem install --file Gemfile \
    && apt-get purge -y --auto-remove \
                     -o APT::AutoRemove::RecommendsImportant=false \
                     $BUILD_DEPS \
    && rm -rf /tmp/* \
              /var/lib/apt/lists/* \
              /usr/lib/ruby/gems/*/cache/*.gem \
              /var/log/* \
              /var/tmp/*

COPY plugin/out_gelf.rb /etc/fluent/plugin/out_gelf.rb
COPY fluent.conf /etc/fluent/fluent.conf
COPY run.sh /run.sh

RUN chmod +x /run.sh

ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.1

CMD /run.sh $FLUENTD_ARGS

HEALTHCHECK none
