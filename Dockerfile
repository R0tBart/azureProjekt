# Use an official Node.js runtime as the base image
FROM node:18-alpine
# Set working directory in the container
WORKDIR /app
# Copy package.json and package-lock.json (if present)
COPY package*.json ./
# Install dependencies (production only, no dev dependencies)
RUN npm install --production
# Copy the rest of the application code
COPY . .
# Expose the port (optional, for documentation)
EXPOSE 3000
# Start the application
CMD ["node", "index.js"]