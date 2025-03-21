ARG NODE_VERSION=22.14.0

FROM node:${NODE_VERSION}

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json files to the working directory
COPY ./package.json /app/
COPY ./package-lock.json /app/

## Install dependencies
RUN npm install

# Copy the rest of the application files to the working directory
COPY . ./

# Set the working directory inside the container
WORKDIR /app

# Expose the port the application will run on
EXPOSE 4000

ENV DB_CONNECTION_STRING=postgres://dbuser:dbpass@postgres:5432/development


# Install pm2
RUN npm install pm2@latest -g

# Start the application
CMD ["pm2-runtime", "bin/www"] 
