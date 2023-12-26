FROM 773096937500.dkr.ecr.us-west-2.amazonaws.com/docyt/ruby-base:v2.6.3

ARG BUNDLER_OPTS="--without development test"

COPY Gemfile ./
COPY Gemfile.lock ./
RUN bundle install --deployment ${BUNDLER_OPTS}

COPY --chown=docyt:docyt . .

RUN pip install -r requirements.txt

USER ${DOCYT_USER}

CMD ["bin/server.sh"]
