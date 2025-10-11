# Dockerfile

# Use a standard Node.js image with Debian base
FROM node:20-slim

# Install dependencies for RobotJS to function properly, including X11
# CRITICAL FIX: Add python3, build-essential, and X11 development headers.
RUN apt-get update && apt-get install -y \
    libxtst6 \
    libxrender1 \
    libxkbcommon-x11-0 \
    libxmu6 \
    xdotool \
    python3 \
    build-essential \
    libx11-dev \
    libxtst-dev \
    libpng-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*


# Set the working directory inside the container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json (if present)
COPY package*.json ./

# Install project dependencies
# --unsafe-perm is often necessary for native modules like robotjs
RUN npm install --unsafe-perm

# Copy the rest of the application code
COPY . .

# Expose the web and UDP ports
EXPOSE 3000
EXPOSE 8080/udp

# Command to run the application
CMD [ "node", "index.js" ]