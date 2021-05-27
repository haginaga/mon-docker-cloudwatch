

help: ## Show help.
	@echo "make [opsitons]"
	@echo "options:"
	@grep -E '^[a-zA-Z_-\%]+:.*?## .*$$' $(MAKEFILE_LIST) \
                | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}'

meta-set-server-ip:  ## Set aws-meta-server ip to eth0. (169.254.169.254)
	sudo ip addr add 169.254.169.254/32 dev eth0
	ip addr show eth0

meta-id:  ## Get instance-id from aws-meta-server.
	curl http://169.254.169.254/latest/meta-data/instance-id

meta-server-up:  ## Start local aws-meta-server.
	( cd aws-meta && docker-compose up -d )

meta-server-down: ## Stop local aws-meta-server.
	( cd aws-meta && docker-compose down )


test-containers-up:  ## Start containers for testing.
	( cd containers && docker-compose up -d )

test-containers-down:  ## Stop containers for testing.
	( cd containers && docker-compose down )


test-run-sh:  ## Start mon-docker-cloudwatch as shell.
	( cd .. && sh mon-docker-cloudwatch.sh )

test-run-docker:  ## Start mon-docker-cloudwatch as docker.
	( cd .. && docker-compose build && docker-compose up )


# EOF
