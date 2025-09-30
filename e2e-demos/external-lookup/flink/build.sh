#!/bin/bash

# Payment Claims Enrichment - Build Script
# This script builds the Flink Table API application and optionally creates Docker image

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="payment-claims-enrichment"
VERSION="1.0-SNAPSHOT"
IMAGE_NAME="${APP_NAME}:latest"
DOCKER_PLATFORM="darwin/arm64"


# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists mvn; then
        print_error "Maven not found. Please install Maven 3.6+"
        exit 1
    fi
    
    if ! command_exists java; then
        print_error "Java not found. Please install Java 11+"
        exit 1
    fi
    
    # Check Java version
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F '.' '{print $1}')
    if [ "$JAVA_VERSION" -lt 11 ]; then
        print_error "Java 11+ required. Found Java $JAVA_VERSION"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Clean previous builds
clean() {
    print_status "Cleaning previous builds..."
    mvn clean -q
    print_success "Clean completed"
}

# Run tests
run_tests() {
    if [ "$SKIP_TESTS" = "true" ]; then
        print_warning "Skipping tests"
        return 0
    fi
    
    print_status "Running tests..."
    mvn test -q
    print_success "Tests passed"
}

# Build application
build() {
    print_status "Building application..."
    mvn package -DskipTests=true -q
    
    if [ -f "target/${APP_NAME}-${VERSION}.jar" ]; then
        print_success "Build completed: target/${APP_NAME}-${VERSION}.jar"
    else
        print_error "Build failed - JAR file not found"
        exit 1
    fi
}

# Build Docker image
build_docker() {
    if [ "$BUILD_DOCKER" != "true" ]; then
        return 0
    fi
    
    if ! command_exists docker; then
        print_warning "Docker not found. Skipping Docker build"
        return 0
    fi
    
    print_status "Building Docker image..."
    
    # Build for specified platform or default to linux/amd64 to avoid warnings
    if [ -n "$DOCKER_PLATFORM" ]; then
        docker build --platform="$DOCKER_PLATFORM" -t "$IMAGE_NAME" .
    else
        docker build --platform=linux/amd64 -t "$IMAGE_NAME" .
    fi
    
    print_success "Docker image built: $IMAGE_NAME"
}

# Create distribution package
create_distribution() {
    if [ "$CREATE_DIST" != "true" ]; then
        return 0
    fi
    
    print_status "Creating distribution package..."
    
    DIST_DIR="dist"
    rm -rf "$DIST_DIR"
    mkdir -p "$DIST_DIR"
    
    # Copy JAR file
    cp "target/${APP_NAME}-${VERSION}.jar" "$DIST_DIR/"
    
    # Copy configuration files
    cp -r src/main/resources "$DIST_DIR/"
    
    # Copy documentation
    cp README.md "$DIST_DIR/"
    cp Dockerfile "$DIST_DIR/"
    
    # Create run script
    cat > "$DIST_DIR/run.sh" << 'EOF'
#!/bin/bash
java -jar payment-claims-enrichment-1.0-SNAPSHOT.jar
EOF
    chmod +x "$DIST_DIR/run.sh"
    
    # Create archive
    tar -czf "${APP_NAME}-${VERSION}.tar.gz" -C "$DIST_DIR" .
    
    print_success "Distribution package created: ${APP_NAME}-${VERSION}.tar.gz"
}

# Print build information
print_build_info() {
    echo
    echo "========================================="
    echo "  Payment Claims Enrichment - Build Info"
    echo "========================================="
    echo "Application: $APP_NAME"
    echo "Version: $VERSION"
    echo "Java Version: $(java -version 2>&1 | head -n 1)"
    echo "Maven Version: $(mvn --version | head -n 1)"
    if [ -f "target/${APP_NAME}-${VERSION}.jar" ]; then
        echo "JAR Size: $(du -h "target/${APP_NAME}-${VERSION}.jar" | cut -f1)"
    fi
    if [ "$BUILD_DOCKER" = "true" ] && command_exists docker; then
        echo "Docker Image: $IMAGE_NAME"
    fi
    echo "========================================="
    echo
}

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -c, --clean         Clean before build"
    echo "  -t, --skip-tests    Skip running tests"
    echo "  -d, --docker        Build Docker image"
    echo "  -p, --package       Create distribution package"
    echo "  -a, --all           Build with all options (clean, tests, docker, package)"
    echo
    echo "Examples:"
    echo "  $0                  # Basic build"
    echo "  $0 --clean --docker # Clean build with Docker image"
    echo "  $0 --all           # Full build with all options"
}

# Parse command line arguments
CLEAN=false
SKIP_TESTS=false
BUILD_DOCKER=true
CREATE_DIST=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -t|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -d|--docker)
            BUILD_DOCKER=true
            shift
            ;;
        -p|--package)
            CREATE_DIST=true
            shift
            ;;
        -a|--all)
            CLEAN=true
            SKIP_TESTS=false
            BUILD_DOCKER=true
            CREATE_DIST=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main build process
main() {
    print_status "Starting build process..."
    
    check_prerequisites
    
    if [ "$CLEAN" = "true" ]; then
        clean
    fi
    
    run_tests
    build
    build_docker
    create_distribution
    
    print_build_info
    print_success "Build process completed successfully!"
}

# Run main function
main "$@"
