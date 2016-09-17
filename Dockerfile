FROM centos:7
MAINTAINER jvassev@gmail.com

# in case running on overlay driver
VOLUME /tmp/.control

ENTRYPOINT ["/start.sh"]

RUN ln -s /ansinetes/ansible /etc/ansible || true

RUN curl -s -L -o /usr/bin/cfssl https://pkg.cfssl.org/R1.1/cfssl_linux-amd64 && \
    curl -s -L -o /usr/bin/cfssljson https://pkg.cfssl.org/R1.1/cfssljson_linux-amd64 && \
    chmod +x      /usr/bin/{cfssl,cfssljson}

RUN yum -y install python-setuptools openssh python-crypto && \
	easy_install pip && \
	pip install setuptools -U

RUN yum -y install gcc openssl-devel python-devel libffi-devel && \
    pip install ansible==2.1.1.0 && \
    yum -y remove  gcc openssl-devel python-devel

COPY start.sh /

COPY _defaults /_defaults
