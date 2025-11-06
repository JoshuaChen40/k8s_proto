# =========================================================
# 🧩 K8s Prototype: One-Click Init (Kind + Ingress + Jupyter)
# =========================================================

# Versions
KIND_VERSION := 0.23.0
KUBECTL_VERSION := 1.30.0
K9S_VERSION := 0.32.5

# Cluster Config
CLUSTER_NAME := k8s-proto
KIND_CONFIG := /usr/k8s_proto/kind/kind-cluster.yml

# Helm Chart Info
HELM_RELEASE := jupyterlab
HELM_CHART := /usr/k8s_proto/helm/jupyter
HELM_NAMESPACE := jupyter

# Ingress NodePorts
HTTP_PORT := 31080
HTTPS_PORT := 31443

# ---------------------------------------------------------
# Default Target
# ---------------------------------------------------------
.PHONY: init env cluster ingress deploy verify open clean

init: env cluster ingress deploy verify open
	@echo "\n🎉 All setup completed! Visit → http://localhost:8080"

# =========================================================
# 🧱 Environment Setup (Safe Installation)
# =========================================================
env: docker kind kubectl helm k9s
	@echo "✅ Environment setup finished."

docker:
	@echo "🐳 Checking Docker..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Installing Docker Engine..."; \
		sudo apt update && sudo apt install -y docker.io && \
		sudo systemctl enable docker && sudo systemctl start docker; \
	else echo "✅ Docker already installed, skipping."; fi
	@docker ps >/dev/null 2>&1 && echo "Docker is running ✔" || echo "⚠️ Docker service may not be running."

kind:
	@echo "📦 Checking kind..."
	@if ! command -v kind >/dev/null 2>&1; then \
		echo "Installing kind v$(KIND_VERSION)..."; \
		sudo curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v$(KIND_VERSION)/kind-linux-amd64 && \
		sudo chmod +x /usr/local/bin/kind; \
	else echo "✅ kind already installed, skipping."; fi
	@kind version || true

kubectl:
	@echo "☸️ Checking kubectl..."
	@if ! command -v kubectl >/dev/null 2>&1; then \
		echo "Installing kubectl v$(KUBECTL_VERSION)..."; \
		sudo rm -f /etc/apt/sources.list.d/kubernetes.list; \
		sudo mkdir -p /etc/apt/keyrings; \
		curl -fsSL https://pkgs.k8s.io/core:/stable:/v$(KUBECTL_VERSION)/deb/Release.key | \
			sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg; \
		echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$(KUBECTL_VERSION)/deb/ /" | \
			sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null; \
		sudo apt update && sudo apt install -y kubectl; \
	else echo "✅ kubectl already installed, skipping."; fi
	@kubectl version --client || true

helm:
	@echo "⛵ Checking Helm..."
	@if ! command -v helm >/dev/null 2>&1; then \
		echo "Installing Helm..."; \
		curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; \
	else echo "✅ Helm already installed, skipping."; fi
	@helm version || true

k9s:
	@echo "🧭 Checking k9s..."
	@if ! command -v k9s >/dev/null 2>&1; then \
		echo "Installing k9s v$(K9S_VERSION)..."; \
		wget -q https://github.com/derailed/k9s/releases/download/v$(K9S_VERSION)/k9s_linux_amd64.deb && \
		sudo apt install -y ./k9s_linux_amd64.deb && rm k9s_linux_amd64.deb; \
	else echo "✅ k9s already installed, skipping."; fi
	@k9s version || true

# =========================================================
# 🚀 Cluster Setup
# =========================================================
cluster:
	@echo "🌍 Creating Kind cluster $(CLUSTER_NAME)..."
	@if ! kind get clusters | grep -q $(CLUSTER_NAME); then \
		kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG); \
	else \
		echo "✅ Kind cluster '$(CLUSTER_NAME)' already exists, skipping."; \
	fi
	@kubectl get nodes -o wide

# =========================================================
# 🌐 Ingress Setup
# =========================================================
ingress:
	@echo "🌐 Installing NGINX Ingress Controller..."
	@if ! kubectl get ns ingress-nginx >/dev/null 2>&1; then \
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml; \
	else echo "✅ ingress-nginx already installed, skipping."; fi
	@echo "⏳ Waiting for ingress controller..."
	@kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s
	@echo "🔧 Patching service to use fixed NodePorts..."
	@kubectl patch svc ingress-nginx-controller -n ingress-nginx \
	  -p '{"spec": {"type": "NodePort", "ports": [{"name":"http","port":80,"nodePort":$(HTTP_PORT),"protocol":"TCP"}, {"name":"https","port":443,"nodePort":$(HTTPS_PORT),"protocol":"TCP"}]}}' >/dev/null || true
	@kubectl get svc -n ingress-nginx

# =========================================================
# 📦 Deploy JupyterLab
# =========================================================
deploy:
	@echo "📦 Deploying JupyterLab..."
	@if ! helm list -n $(HELM_NAMESPACE) | grep -q $(HELM_RELEASE); then \
		helm install $(HELM_RELEASE) $(HELM_CHART) --namespace $(HELM_NAMESPACE) --create-namespace; \
	else \
		echo "🌀 JupyterLab already deployed, upgrading..."; \
		helm upgrade $(HELM_RELEASE) $(HELM_CHART) --namespace $(HELM_NAMESPACE); \
	fi
	@kubectl rollout status deployment/$(HELM_RELEASE)-jupyterlab -n $(HELM_NAMESPACE)
	@kubectl get pods -n $(HELM_NAMESPACE)

# =========================================================
# 🧩 Verification & Access
# =========================================================
verify:
	@echo "\n🔍 Checking Ingress & Services..."
	@kubectl get ingress -n $(HELM_NAMESPACE)
	@kubectl get svc -n $(HELM_NAMESPACE)
	@echo "\n✅ Verify complete."

open:
	@echo "\n🌐 Open JupyterLab at: http://localhost:8080"
	@echo "Use this command if needed:"
	@echo "kubectl port-forward svc/ingress-nginx-controller -n ingress-nginx 8080:80"

# =========================================================
# 🧹 Cleanup
# =========================================================
clean:
	@echo "🧹 Cleaning up environment..."
	-helm uninstall $(HELM_RELEASE) -n $(HELM_NAMESPACE) || true
	-kubectl delete ns $(HELM_NAMESPACE) || true
	-kind delete cluster --name $(CLUSTER_NAME) || true
	@echo "✅ Cleanup completed."
