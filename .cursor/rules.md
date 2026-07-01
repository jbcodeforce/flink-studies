# Cursor Rules for External Lookup Project

## Deployment Automation Rules

### Rule: No Separate Deployment Scripts
- **NEVER** create `deploy.sh`, `cleanup.sh`, or similar shell scripts for Kubernetes deployments
- **ALWAYS** implement deployment logic directly in Makefile targets
- Use `kubectl` commands directly in Makefile rules with proper error handling
- Implement idempotent deployment targets that can be run multiple times safely

### Rule: Makefile-First Approach
- All deployment, cleanup, and management operations should be Makefile targets
- Use `@echo` for status messages with colored output
- Include proper error handling with `|| true` where appropriate
- Implement `help` target as the default with clear descriptions

### Rule: Kubernetes Resource Management
- Group related `kubectl apply` commands in logical deployment targets
- Always use `--ignore-not-found` for cleanup operations
- Include `kubectl wait` commands for readiness checks
- Implement separate targets for different components (e.g., `deploy-prometheus`, `deploy-grafana`)

### Rule: Port Forwarding in Makefiles
- Handle port forwarding setup and cleanup in Makefile targets
- Use background processes with PID tracking when necessary
- Provide clear instructions for manual port forwarding as fallback

### Example Pattern:
```makefile
deploy-component: ## Deploy specific component
	@echo "🚀 Deploying component..."
	@kubectl apply -f config.yaml
	@kubectl apply -f deployment.yaml
	@kubectl wait --for=condition=available --timeout=300s deployment/component -n $(NAMESPACE)
	@echo "✅ Component deployed successfully!"

clean-component: ## Remove specific component
	@echo "🗑️ Removing component..."
	@kubectl delete -f deployment.yaml --ignore-not-found
	@kubectl delete -f config.yaml --ignore-not-found
	@echo "✅ Component removed!"
```

This approach keeps all deployment logic centralized, version-controlled, and easily maintainable within the Makefile structure.
