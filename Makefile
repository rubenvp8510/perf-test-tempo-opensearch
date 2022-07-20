
.PHONY: start-minikube
start-minikube:
	minikube start --memory=20g --cpus=8 --disk-size=50g --bootstrapper=kubeadm --extra-config=kubelet.authentication-token-webhook=true --extra-config=kubelet.authorization-mode=Webhook --extra-config=scheduler.bind-address=0.0.0.0 --extra-config=controller-manager.bind-address=0.0.0.0  --docker-opt="default-ulimit=nofile=102400:102400"
	#minikube start --memory=20g --cpus=8 --bootstrapper=kubeadm --extra-config=kubelet.authentication-token-webhook=true --extra-config=kubelet.authorization-mode=Webhook --extra-config=scheduler.bind-address=0.0.0.0 --extra-config=controller-manager.bind-address=0.0.0.0
	minikube ssh "sudo sysctl -w vm.max_map_count=262144" # VM restart might be needed

.PHONY: deploy-monitoring
deploy-monitoring:
	git submodule update --init --recursive
	kubectl apply --server-side -f kube-prometheus/manifests/setup
	until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done
	kubectl apply -f kube-prometheus/manifests/

.PHONY: deploy-jaeger-operator
deploy-jaeger-operator:
	kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.yaml
	sleep 50 # wait until cert manager is up and ready
	kubectl create namespace observability || true
	kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.35.0/jaeger-operator.yaml -n observability # <2>

.PHONY: deploy-test-opensearch
deploy-test-opensearch:
	kubectl create namespace test-opensearch || true
	helm repo add opensearch https://opensearch-project.github.io/helm-charts/
	# deploy OpenSearch 1.3.3
	helm install opensearch-cluster -f opensearch-helm-values.yaml --namespace test-opensearch opensearch/opensearch --version 1.13.0 || true
	kubectl apply -f ./resources-opensearch -n test-opensearch

.PHONY: port-forward-grafana
port-forward-grafana:
	kubectl port-forward svc/grafana 3000:3000 -n monitoring

.PHONY: port-forward-opensearch
port-forward-opensearch:
	kubectl port-forward svc/opensearch-cluster-master 9200:9200 -n test-opensearch

.PHONY: port-forward-jaeger-test-opensearch
port-forward-jaeger-test-opensearch:
	kubectl port-forward svc/simple-prod-query 16686:16686 -n test-opensearch
