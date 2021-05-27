FROM amazon/aws-cli:latest

RUN yum install -y curl jq docker

COPY mon-docker-cloudwatch.sh /mon-docker-cloudwatch.sh

ENTRYPOINT ["/mon-docker-cloudwatch.sh"]

CMD ["sh"]

