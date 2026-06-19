# Stage 1: Build the statically linked Go binary
FROM golang:1.22-alpine AS builder

WORKDIR /app

# Download Go modules
COPY go.mod go.sum ./
RUN go mod download

# Copy the entire backend source code
COPY . .

# Build the Go app as a statically linked binary
# CGO_ENABLED=0 disables CGO, ensuring the binary has no dynamic C library dependencies.
# GOOS=linux ensures we are compiling for the correct OS target.
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bpsc-api .

# Stage 2: Create a minimal production image
FROM alpine:latest

WORKDIR /root/

# Install ca-certificates. This is CRITICAL for the backend to establish 
# secure HTTPS connections to external APIs like the Gemini API.
RUN apk --no-cache add ca-certificates

# Copy the compiled binary from the builder stage
COPY --from=builder /app/bpsc-api .

# Expose port 8080 to the outside world
EXPOSE 8080

# Command to run the executable
CMD ["./bpsc-api"]
