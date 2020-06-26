# postgres
FROM postgres:alpine as postgres

ENV POSTGRES_PASSWORD=password
ENV POSTGRES_USER=dev
ENV POSTGRES_DB=feedback

# api
FROM node:10.13-alpine as node_1

WORKDIR /app

ENV DATABASE_URL postgres://dev:password@postgres/feedback
ENV USE_TEST_DATA 0
ENV USE_TEST_AUTH 0
ENV APP_COOKIE_SECRET testsecret

COPY ./misc /misc

COPY server/ .
COPY docker/production/api /prod
COPY .git/ /.git
RUN sh /prod/docker-build.sh

###
FROM node:10.13-alpine as node_2

WORKDIR /app

COPY --from=node_1 /app /app

CMD npm start -- --config config.json

# Proxy
FROM golang:1.11-alpine as go_1

WORKDIR /app

ENV FFGP_DB_DRIVER postgres
ENV FFGP_DB_CONNECT postgres://dev:password@postgres/$feedback?sslmode=disable
ENV FFGP_INJECT_SCRIPT http://localhost:8080/embed.js


COPY --from=node_2 /app /app

RUN apk add --no-cache git build-base

COPY proxy .

RUN go build

###
FROM golang:1.11-alpine as go_2

WORKDIR /app

COPY --from=go_1 /app/proxy /app/proxy
CMD /app/proxy

# Nginx
FROM node:10.13-alpine as node_3

WORKDIR /app

ENV APP_DOMAIN localhost
#ENV host localhost
COPY --from=go_2 /app /app

COPY .git /.git
COPY client/ .
COPY misc/ /misc

RUN apk add --no-cache git

RUN rm -rf node_modules/

RUN npm install
RUN npm run build

###
FROM nginx:alpine as nginx

WORKDIR /app
COPY --from=node_3 /app /app

COPY docker/production/nginx/nginx.conf /app/nginx.conf

RUN sed -i '11c \    listen 8080;' nginx.conf 
RUN sed -i '32c \    listen 8080;' nginx.conf 
RUN sed '31a \     resolve 127.0.0.1;' < nginx.conf
EXPOSE 8080
CMD envsubst '\localhost' < /app/nginx.conf > /etc/nginx/nginx.conf && nginx -g 'daemon off;'

