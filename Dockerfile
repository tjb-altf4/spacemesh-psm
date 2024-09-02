# -------------------------------------------------------------------------------------------------
# Stage 1: Build grpcurl with Go 1.19
FROM golang:1.19 as builder

# Set up Go environment
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

# Define build argument for the tag
ARG GRPCURL_TAG=master

# Clone grpcurl repository and checkout the specified tag
RUN git clone https://github.com/fullstorydev/grpcurl.git /go/src/github.com/fullstorydev/grpcurl && \
    cd /go/src/github.com/fullstorydev/grpcurl && \
    git checkout ${GRPCURL_TAG} && \
    cd cmd/grpcurl && \
    go build -o /usr/local/bin/grpcurl

# -------------------------------------------------------------------------------------------------
# Stage 2: Create the final image
FROM ubuntu:22.04

# set default log level as INFO
ENV PSM_LOG_LEVEL=3

# Set the timezone
ENV TZ="UTC"

# Install necessary packages and clean up
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y \
        bash \
        jq \
        bc \
        iputils-ping \
        netcat-traditional \
        curl \
        docker.io \
        tzdata && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata

# Copy grpcurl from the builder stage
COPY --from=builder /usr/local/bin/grpcurl /usr/local/bin/grpcurl

# Create a top-level directory for the configuration file
RUN mkdir -p /psm

# Copy your script into the container
COPY psm.sh /usr/local/bin/
COPY docker-entrypoint.sh /usr/local/bin/

# Make your script executable
RUN chmod +x /usr/local/bin/psm.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["bash", "-c", "psm.sh"]
