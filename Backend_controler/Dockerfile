FROM node:18-bookworm

WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python-is-python3 \
    make \
    g++ \
 && rm -rf /var/lib/apt/lists/*

COPY package*.json ./

RUN sed -i '/"node-addon-api"/d' package.json && \
    npm install --omit=dev

# Copy all source code
COPY . ./

# Expose your ports
EXPOSE 3000 8080

# Start the app
CMD ["node", "index.js"]
