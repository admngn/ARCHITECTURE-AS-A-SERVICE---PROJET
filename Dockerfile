FROM node:18

WORKDIR /app

# Copie le code source depuis le dossier resources
COPY resources/codebase_partner/package*.json ./
RUN npm install && npm install aws-sdk

COPY resources/codebase_partner/ .

ENV APP_PORT=80
EXPOSE 80

CMD ["npm", "start"]
