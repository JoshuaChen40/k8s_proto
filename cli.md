
## 使用 kind 配置 Cluster
```
# 配置 cluster
kind create cluster --name k8s-proto --config /usr/k8s_proto/kind/kind-cluster.yml
## kind delete cluster --name k8s-proto

# 檢查cluster、node
kind get clusters
kubectl get nodes
```

## 配置 Ingress 
```
# 安裝 NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# 檢查安裝狀態
kubectl get pods -n ingress-nginx -w

# 確認 Service 對外端口
kubectl get svc -n ingress-nginx

# 明確設定固定 port
kubectl patch svc ingress-nginx-controller -n ingress-nginx \
  -p '{"spec": {"type": "NodePort", "ports": [
      {"name": "http","port":80,"nodePort":31080,"protocol":"TCP"},
      {"name": "https","port":443,"nodePort":31443,"protocol":"TCP"}
  ]}}'
```

## 佈署 Pod
```
helm install jupyterlab /usr/k8s_proto/helm/jupyter --namespace jupyter --create-namespace
## helm upgrade jupyterlab /usr/k8s_proto/helm/jupyter --namespace jupyter
## helm upgrade jupyterlab /usr/k8s_proto/helm/jupyter --namespace jupyter --dry-run --debug
## helm uninstall jupyterlab -n jupyter

# 先確認 JupyterLab Pod 正常運作
kubectl get pods -n jupyter -w
## kubectl describe pod -n jupyter jupyterlab-jupyterlab-fdf57b5f6-7lh6b | tail -n 20

# 確認 Ingress 對應的 Host 和 Path
kubectl get ingress -n jupyter
```

## 開啟Jupyter
```
http://localhost:8080
```