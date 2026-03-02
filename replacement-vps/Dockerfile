FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --production

COPY index.js ./

ENV NODE_ENV=production
ENV DATA_DIR=/data

VOLUME /data

ENTRYPOINT ["node", "index.js"]
