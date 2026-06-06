# syntax=docker/dockerfile:1
FROM ruby:4.0.5

RUN apt-get update -y -qq && apt-get install -yq mysql-client vim

WORKDIR /chess_event_map
# COPY Gemfile /chess_event_map/Gemfile
# COPY Gemfile.lock /chess_event_map/Gemfile.lock
RUN bundle install

# Add a script to be executed every time the container starts.
# COPY entrypoint.sh /usr/bin/
# RUN chmod +x /usr/bin/entrypoint.sh
# ENTRYPOINT ["entrypoint.sh"]
# EXPOSE 3000

# Configure the main process to run when running the image
# CMD ["rails", "server", "-b", "0.0.0.0"]