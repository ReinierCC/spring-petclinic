#!/bin/bash
set -e

echo "=========================================="
echo "Spring PetClinic - Containerization Build"
echo "=========================================="
echo ""

# Step 1: Build the application
echo "Step 1: Building application with Maven..."
if [ ! -x ./mvnw ]; then
    echo "Error: Maven wrapper (mvnw) is not executable"
    echo "Run: chmod +x mvnw"
    exit 1
fi
./mvnw package -DskipTests
echo "✓ Application built successfully"
echo ""

# Step 2: Validate Dockerfile against Rego policies
echo "Step 2: Validating Dockerfile against Rego policies..."
if command -v conftest &> /dev/null; then
    conftest test Dockerfile --policy rego/
    echo "✓ Dockerfile passed all Rego policy checks"
else
    echo "⚠ Conftest not installed - skipping policy validation"
    echo "  Install with: brew install conftest (macOS) or see REGO_POLICY_GUIDE.md"
fi
echo ""

# Step 3: Build Docker image
echo "Step 3: Building Docker image..."
docker build -t spring-petclinic:latest .
echo "✓ Docker image built successfully"
echo ""

# Step 4: Display image info
echo "Step 4: Image information..."
docker images spring-petclinic:latest
echo ""

echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo ""
echo "To run the container:"
echo "  docker run -d -p 8080:8080 --name petclinic spring-petclinic:latest"
echo ""
echo "To access the application:"
echo "  http://localhost:8080"
echo ""
echo "To check health:"
echo "  curl http://localhost:8080/actuator/health"
echo ""
