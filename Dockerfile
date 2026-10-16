# syntax=docker/dockerfile:1

############################################
# 1. Build : export statique de la version web
############################################
FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Les variables EXPO_PUBLIC_* sont écrites dans le bundle au moment du build :
# changer d'URL d'API impose de reconstruire l'image.
ARG EXPO_PUBLIC_STRAPI_URL
RUN test -n "$EXPO_PUBLIC_STRAPI_URL" || (echo "EXPO_PUBLIC_STRAPI_URL manquant" && exit 1)
ENV EXPO_PUBLIC_STRAPI_URL=$EXPO_PUBLIC_STRAPI_URL

RUN npx expo export -p web

############################################
# 2. Production : fichiers statiques servis par Nginx
############################################
FROM nginx:1.27-alpine AS prod

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

# Les fichiers de public/ (manifeste, service worker, icônes) sont recopiés
# avec les droits du clone : sur un serveur au umask strict (027), Nginx ne
# peut pas les lire (403 / 404). On les rend lisibles par tous.
RUN chmod -R a+rX /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/ || exit 1
