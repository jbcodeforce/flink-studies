# Makefile for External Lookup Monitoring Stack

# Configuration
NAMESPACE = el-demo
SCRIPT_DIR = $(shell pwd)

.PHONY: help deploy clean status logs port-forward stop-port-forward grafana-dashboard prometheus-dashboard

# Default target
help: ## Show this help message
	@echo "External Lookup Monitoring Stack"
	@echo "================================="
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

use_demo_ns: ## Set kubectl context to use el-demo namespace
	@kubectl config set-context --current --namespace=$(NAMESPACE)

check-namespace: ## Check if namespace exists
	@echo "🔍 Checking namespace: $(NAMESPACE)"
	@kubectl get namespace $(NAMESPACE) >/dev/null 2>&1 || \
		(echo "❌ Namespace $(NAMESPACE) does not exist. Create it with: kubectl create namespace $(NAMESPACE)" && exit 1)
	@echo "✅ Namespace $(NAMESPACE) exists"

deploy: check-namespace deploy-prometheus deploy-grafana ## Deploy complete monitoring stack (Prometheus + Grafana)
	@echo "🚀 Monitoring stack deployment complete!"
	@echo "📋 Next steps:"
	@echo "  make port-forward    # Setup local access"
	@echo "  make status          # Check deployment status"
	@echo "  make info            # Show connection information"

deploy-with-forwarding: deploy port-forward ## Deploy monitoring stack with port forwarding enabled
	@echo "✅ Monitoring stack deployed with port forwarding enabled!"
	@echo "🌐 Access URLs:"
	@echo "  Grafana:    http://localhost:3000 (admin/admin123)"
	@echo "  Prometheus: http://localhost:9090"

deploy-prometheus: ## Deploy only Prometheus
	@echo "🚀 Deploying Prometheus..."
	@kubectl apply -f prometheus-config.yaml
	@echo "📋 Prometheus configuration applied"
	@kubectl apply -f prometheus-deployment.yaml
	@echo "📋 Prometheus deployment applied"
	@echo "⏳ Waiting for Prometheus to be ready..."
	@kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n $(NAMESPACE)
	@echo "✅ Prometheus deployed successfully!"

deploy-grafana: ## Deploy only Grafana
	@echo "🚀 Deploying Grafana..."
	@kubectl apply -f grafana-configmap.yaml
	@echo "📋 Grafana configuration applied"
	@kubectl apply -f grafana-deployment.yaml
	@echo "📋 Grafana deployment applied"
	@echo "⏳ Waiting for Grafana to be ready..."
	@kubectl wait --for=condition=available --timeout=300s deployment/grafana -n $(NAMESPACE)
	@echo "✅ Grafana deployed successfully!"

status: ## Check deployment status
	@echo "📊 Monitoring Stack Status"
	@echo "=========================="
	@echo "Namespace: $(NAMESPACE)"
	@echo ""
	@echo "📦 Pods:"
	@kubectl get pods -n $(NAMESPACE) -l 'app in (prometheus,grafana)' -o wide
	@echo ""
	@echo "🔗 Services:"
	@kubectl get services -n $(NAMESPACE) -l 'app in (prometheus,grafana)' -o wide
	@echo ""
	@echo "🌐 Ingresses:"
	@kubectl get ingresses -n $(NAMESPACE) -l 'app in (prometheus,grafana)' -o wide

logs-prometheus: ## Show Prometheus logs
	@echo "📋 Prometheus Logs:"
	@kubectl logs -f deployment/prometheus -n $(NAMESPACE)

logs-grafana: ## Show Grafana logs
	@echo "📋 Grafana Logs:"
	@kubectl logs -f deployment/grafana -n $(NAMESPACE)

port-forward: ## Setup port forwarding for local access
	@echo "🔗 Setting up port forwarding..."
	@echo "Prometheus: http://localhost:9090"
	@kubectl port-forward service/prometheus-service 9090:9090 -n $(NAMESPACE) &
	@echo "Grafana: http://localhost:3000 (admin/admin123)"
	@kubectl port-forward service/grafana-service 3000:3000 -n $(NAMESPACE) &
	@echo "✅ Port forwarding active. Press Ctrl+C to stop."

stop-port-forward: ## Stop port forwarding processes
	@echo "🛑 Stopping port forwarding processes..."
	@pkill -f "kubectl port-forward.*prometheus-service" || true
	@pkill -f "kubectl port-forward.*grafana-service" || true
	@rm -f /tmp/monitoring-port-forward.pids
	@echo "✅ Port forwarding stopped"

grafana-dashboard: ## Open Grafana dashboard in browser (requires port-forward)
	@echo "🌐 Opening Grafana dashboard..."
	@open http://localhost:3000 || xdg-open http://localhost:3000 || echo "Please open http://localhost:3000 manually"

prometheus-dashboard: ## Open Prometheus dashboard in browser (requires port-forward)
	@echo "🌐 Opening Prometheus dashboard..."
	@open http://localhost:9090 || xdg-open http://localhost:9090 || echo "Please open http://localhost:9090 manually"

test-metrics: ## Test if metrics endpoints are accessible
	@echo "🧪 Testing metrics endpoints..."
	@echo "Testing Prometheus health:"
	@kubectl exec -n $(NAMESPACE) deployment/prometheus -- wget -q -O- http://localhost:9090/-/healthy || echo "❌ Prometheus health check failed"
	@echo "Testing Grafana health:"
	@kubectl exec -n $(NAMESPACE) deployment/grafana -- wget -q -O- http://localhost:3000/api/health || echo "❌ Grafana health check failed"
	@echo "✅ Metrics endpoints test completed"

restart-prometheus: ## Restart Prometheus deployment
	@echo "🔄 Restarting Prometheus..."
	@kubectl rollout restart deployment/prometheus -n $(NAMESPACE)
	@kubectl rollout status deployment/prometheus -n $(NAMESPACE)
	@echo "✅ Prometheus restarted"

restart-grafana: ## Restart Grafana deployment
	@echo "🔄 Restarting Grafana..."
	@kubectl rollout restart deployment/grafana -n $(NAMESPACE)
	@kubectl rollout status deployment/grafana -n $(NAMESPACE)
	@echo "✅ Grafana restarted"

restart: restart-prometheus restart-grafana ## Restart both Prometheus and Grafana

update-config: ## Update configurations (ConfigMaps)
	@echo "🔄 Updating configurations..."
	@kubectl apply -f prometheus-config.yaml
	@kubectl apply -f grafana-configmap.yaml
	@echo "📝 Configurations updated. Consider restarting pods:"
	@echo "make restart"

clean: stop-port-forward ## Remove all monitoring stack components
	@echo "🗑️  Removing monitoring stack from namespace: $(NAMESPACE)"
	@echo "🗑️  Removing Grafana..."
	@kubectl delete -f grafana-deployment.yaml --ignore-not-found
	@kubectl delete -f grafana-configmap.yaml --ignore-not-found
	@echo "🗑️  Removing Prometheus..."
	@kubectl delete -f prometheus-deployment.yaml --ignore-not-found
	@kubectl delete -f prometheus-config.yaml --ignore-not-found
	@echo "⏳ Waiting for resources to be terminated..."
	@sleep 5
	@echo "📊 Checking cleanup status..."
	@REMAINING_PODS=$$(kubectl get pods -n $(NAMESPACE) -l 'app in (prometheus,grafana)' --no-headers 2>/dev/null | wc -l); \
	if [ "$$REMAINING_PODS" -eq 0 ]; then \
		echo "✅ No monitoring pods remaining"; \
	else \
		echo "⚠️  $$REMAINING_PODS monitoring pods still exist (may be terminating)"; \
		kubectl get pods -n $(NAMESPACE) -l 'app in (prometheus,grafana)'; \
	fi
	@echo "✅ Monitoring stack cleanup completed!"

# Development helpers
dev-setup: deploy port-forward ## Quick development setup (deploy + port-forward)
	@echo "🚀 Development environment ready!"
	@echo "Grafana: http://localhost:3000 (admin/admin123)"
	@echo "Prometheus: http://localhost:9090"

# Show connection info
info: ## Show connection information
	@echo "📋 External Lookup Monitoring Stack Information"
	@echo "=============================================="
	@echo "Namespace: $(NAMESPACE)"
	@echo ""
	@echo "🎯 Access URLs (with port-forward):"
	@echo "  Grafana:    http://localhost:3000"
	@echo "  Prometheus: http://localhost:9090"
	@echo ""
	@echo "🔐 Credentials:"
	@echo "  Grafana: admin/admin123"
	@echo ""
	@echo "📊 Key Dashboards:"
	@echo "  - External Lookup Application Dashboard"
	@echo ""
	@echo "⚡ Quick Commands:"
	@echo "  make deploy          # Deploy stack"
	@echo "  make port-forward    # Setup local access"
	@echo "  make status          # Check status"
	@echo "  make logs-grafana    # View Grafana logs"
	@echo "  make clean           # Remove everything"

all: clean deploy port-forward ## Full deployment pipeline
	@echo "✅ Complete monitoring stack deployed and ready!"
