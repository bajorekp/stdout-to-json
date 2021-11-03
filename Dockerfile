FROM ruby:2.1-alpine

RUN gem install rspec

WORKDIR /app

CMD rspec /app/*_spec.rb