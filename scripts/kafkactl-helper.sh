#!/bin/bash

# kafkactl Helper Script for KNEP Multi-tenant Setup
# This script provides convenient commands for working with kafkactl contexts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check if kafkactl is installed
check_kafkactl() {
    if ! command -v kafkactl &> /dev/null; then
        print_error "kafkactl is not installed. Please install it first:"
        echo "  brew install deviceinsight/packages/kafkactl"
        echo "  # or"
        echo "  go install github.com/deviceinsight/kafkactl@latest"
        exit 1
    fi
}

# Function to show current context
show_context() {
    print_info "Current kafkactl context:"
    kafkactl config current-context
}

# Function to list all contexts
list_contexts() {
    print_info "Available kafkactl contexts:"
    kafkactl config get-contexts
}

# Function to switch context
switch_context() {
    local context=$1
    if [ -z "$context" ]; then
        print_error "Please specify a context: team-a, team-b, kafka-direct, or knep-direct"
        list_contexts
        exit 1
    fi
    
    print_info "Switching to context: $context"
    kafkactl config use-context "$context"
    print_success "Switched to context: $context"
}

# Function to test connection
test_connection() {
    local context=${1:-$(kafkactl config current-context)}
    print_info "Testing connection for context: $context"
    
    if kafkactl --context "$context" get brokers; then
        print_success "Connection successful for context: $context"
    else
        print_error "Connection failed for context: $context"
        print_warning "Make sure the required port-forwards are active or Kong Gateway is accessible"
    fi
}

# Function to create a test topic
create_test_topic() {
    local context=${1:-$(kafkactl config current-context)}
    local topic_name=${2:-"test-topic"}
    
    print_info "Creating topic '$topic_name' in context: $context"
    
    if kafkactl --context "$context" create topic "$topic_name" --partitions 3 --replication-factor 3; then
        print_success "Topic '$topic_name' created successfully"
        print_info "Note: Topic will be prefixed based on the team context (a- or b-)"
    else
        print_error "Failed to create topic '$topic_name'"
    fi
}

# Function to list topics
list_topics() {
    local context=${1:-$(kafkactl config current-context)}
    print_info "Listing topics for context: $context"
    kafkactl --context "$context" get topics
}

# Function to produce test message
produce_message() {
    local context=${1:-$(kafkactl config current-context)}
    local topic=${2:-"test-topic"}
    local message=${3:-"Hello from kafkactl!"}
    
    print_info "Producing message to topic '$topic' in context: $context"
    echo "$message" | kafkactl --context "$context" produce "$topic"
    print_success "Message produced successfully"
}

# Function to consume messages
consume_messages() {
    local context=${1:-$(kafkactl config current-context)}
    local topic=${2:-"test-topic"}
    
    print_info "Consuming messages from topic '$topic' in context: $context"
    print_warning "Press Ctrl+C to stop consuming"
    kafkactl --context "$context" consume "$topic" --from-beginning
}

# Function to setup port forwards
setup_port_forwards() {
    print_info "Setting up port forwards for direct access..."
    
    print_info "Starting port-forward for Kafka cluster (kafka-direct context)..."
    kubectl port-forward svc/my-cluster-kafka-bootstrap 9092:9092 -n kafka &
    KAFKA_PF_PID=$!
    
    print_info "Starting port-forward for KNEP gateway (knep-direct context)..."
    kubectl port-forward svc/knep-gateway 9093:9092 -n knep &
    KNEP_PF_PID=$!
    
    print_success "Port forwards started:"
    print_info "  Kafka cluster: localhost:9092 (PID: $KAFKA_PF_PID)"
    print_info "  KNEP gateway: localhost:9093 (PID: $KNEP_PF_PID)"
    print_warning "Run 'kill $KAFKA_PF_PID $KNEP_PF_PID' to stop port forwards"
}

# Function to show help
show_help() {
    echo "kafkactl Helper Script for KNEP Multi-tenant Setup"
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  context                     Show current context"
    echo "  contexts                    List all available contexts"
    echo "  use <context>              Switch to specified context"
    echo "  test [context]             Test connection for context"
    echo "  topics [context]           List topics for context"
    echo "  create-topic [context] [topic]  Create a test topic"
    echo "  produce [context] [topic] [message]  Produce a message"
    echo "  consume [context] [topic]  Consume messages from topic"
    echo "  port-forwards              Setup port forwards for direct access"
    echo "  help                       Show this help message"
    echo ""
    echo "Available contexts:"
    echo "  team-a        - Team A virtual cluster (topics prefixed with 'a-')"
    echo "  team-b        - Team B virtual cluster (topics prefixed with 'b-')"
    echo "  kafka-direct  - Direct Kafka cluster access (requires port-forward)"
    echo "  knep-direct   - Direct KNEP access (requires port-forward)"
    echo ""
    echo "Examples:"
    echo "  $0 use team-a"
    echo "  $0 test team-a"
    echo "  $0 create-topic team-a my-topic"
    echo "  $0 produce team-a my-topic 'Hello World!'"
    echo "  $0 consume team-a my-topic"
}

# Main script logic
check_kafkactl

case "${1:-help}" in
    "context")
        show_context
        ;;
    "contexts")
        list_contexts
        ;;
    "use")
        switch_context "$2"
        ;;
    "test")
        test_connection "$2"
        ;;
    "topics")
        list_topics "$2"
        ;;
    "create-topic")
        create_test_topic "$2" "$3"
        ;;
    "produce")
        produce_message "$2" "$3" "$4"
        ;;
    "consume")
        consume_messages "$2" "$3"
        ;;
    "port-forwards")
        setup_port_forwards
        ;;
    "help"|*)
        show_help
        ;;
esac
