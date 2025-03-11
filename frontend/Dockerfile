FROM node:20-alpine as builder

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

# Build the application
ENV NEXT_TELEMETRY_DISABLED 1
RUN npm run build

FROM node:20-alpine as runner

ENV NODE_ENV production
ENV API_BASE_URL=http://bible-api:8080

COPY --from=builder /app/next.config.mjs ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

EXPOSE 3000

CMD ["npm", "start"]
