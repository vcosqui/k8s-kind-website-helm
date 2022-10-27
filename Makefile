#!/usr/bin/env make

.PHONY: run_website stop_website run_local_registry create_kind_cluster remove_kind_cluster connect_registry_to_kind \
connect_registry_to_kind_network create_kind_cluster_with_registry build_website port_forward teardown \
kind_nginx_ingress deploy_ingress

build_website:
	docker build -t website.com . && \
	docker tag website.com 127.0.0.1:5000/website.com && \
	docker push 127.0.0.1:5000/website.com

run_website: build_website
	docker run --rm --name website.com -d -p 5001:80 website.com

stop_website:
	docker stop website.com

create_kind_cluster: run_local_registry
	kind create cluster --name website.com  --config ./kind_config.yaml || true;

remove_kind_cluster:
	kind delete cluster --name website.com

stop_local_registry:
	docker stop local-registry || true; \
	docker container rm local-registry || true;

run_local_registry:
	if ! docker ps | grep -q 'local-registry'; \
	then docker run -d -p 5000:5000 --name local-registry --restart=always registry:2; \
	else echo "---> local-registry is already running. There's nothing to do here."; \
	fi

connect_registry_to_kind_network: run_local_registry
	docker network connect kind local-registry || true;

connect_registry_to_kind: connect_registry_to_kind_network
	kubectl apply -f ./kind_configmap.yaml

create_kind_cluster_with_registry:
	$(MAKE) create_kind_cluster && $(MAKE) connect_registry_to_kind

port_forward:
	kubectl port-forward service/website-svc 8080:80

deploy_website:
	kubectl apply -f deployment.yaml
	kubectl apply -f service.yaml

teardown: stop_local_registry remove_kind_cluster
	echo 'teardown'

kind_nginx_ingress:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

deploy_website_ingress:
	kubectl apply -f ingress.yaml