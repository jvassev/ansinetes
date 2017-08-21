FROM centos:7
MAINTAINER jvassev@gmail.com

# in case running on overlay driver
VOLUME /tmp/.control

ENTRYPOINT ["/start.sh"]

RUN ln -s /ansinetes/ansible /etc/ansible || true

RUN curl -s -L -o /usr/bin/cfssl https://pkg.cfssl.org/R1.1/cfssl_linux-amd64 && \
    curl -s -L -o /usr/bin/cfssljson https://pkg.cfssl.org/R1.1/cfssljson_linux-amd64 && \
    chmod +x      /usr/bin/{cfssl,cfssljson}

RUN yum -y install python-setuptools openssh && \
	easy_install pip && \
	pip install setuptools -U

RUN yum -y install gcc openssh-clients openssl openssl-devel python-devel libffi-devel curl && \
    pip install ansible==2.2.3.0 netaddr requests && \
    yum -y remove gcc openssl-devel python-devel && \
    yum clean all

RUN curl -kL# -O https://dl.k8s.io/v1.6.8/kubernetes-client-linux-amd64.tar.gz && \
     tar xzf kubernetes-client-*.tar.gz -C /usr/bin --strip-components 3 && \
     rm kubernetes-client-*.tar.gz

COPY start.sh /

COPY _defaults /_defaults
